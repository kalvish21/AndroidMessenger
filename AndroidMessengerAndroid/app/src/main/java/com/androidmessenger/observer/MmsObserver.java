package com.androidmessenger.observer;

import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.os.Handler;
import android.provider.Telephony;
import android.util.Log;

import com.androidmessenger.R;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.Uris;
import com.androidmessenger.util.UserPreferencesManager;
import com.androidmessenger.util.Util;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by Kalyan Vishnubhatla on 8/21/16.
 */
public class MmsObserver extends ContentObserver {
    private static final String TAG = MmsObserver.class.getSimpleName();
    private Context context;
    private AndroidAppService service;

    public MmsObserver(Handler handler, AndroidAppService service) {
        super(handler);
        this.context = service.getBaseContext();
        this.service = service;
    }

    @Override
    public void onChange(boolean selfChange) {
        super.onChange(selfChange);

        Long largestDateCounted = Long.parseLong(UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_current_mms_counter), "0"));
        String filter = "creator != ? and date > ?";
        String[] args = new String[]{context.getPackageName(), Long.toString(largestDateCounted)};

        Cursor cursor = null;
        try {
            cursor = context.getContentResolver().query(Uris.Mms, null, filter, args, null);
            Util util = new Util();
            long receivedDate = 0;
            JSONArray array = new JSONArray();
            Map<String, String> map = new HashMap<>();
            boolean messages_received = false;

            if (cursor.moveToFirst()) {
                for (int i = 0; i < cursor.getCount(); i++) {

                    Log.i(TAG, "Checking the row ...");
                    // TODO: Ignore all messages outside of sent and received for now
                    String msgBoxValue = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_BOX));
                    if (!(msgBoxValue.contains(String.valueOf(Telephony.Mms.MESSAGE_BOX_INBOX)) ||
                            msgBoxValue.contains(String.valueOf(Telephony.Mms.MESSAGE_BOX_SENT)))) {
                        continue;
                    }


                    String dateSent = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Mms.DATE_SENT));
                    if (msgBoxValue.equals(String.valueOf(Telephony.Mms.MESSAGE_BOX_INBOX)) && dateSent.equals("0")) {
                        // Message is being downloaded and we can ignore it until it is complete.
                        continue;
                    }

                    String id = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Mms._ID));
                    if (map.get(id) != null) {
                        continue;
                    }
                    map.put(id, id);
                    Log.i(TAG, id);

                    // Keep track of the largest date
                    long currentDate = Long.valueOf(cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Mms.DATE)));
                    if (currentDate > largestDateCounted) {
                        receivedDate = currentDate;
                    }

                    JSONObject msg = util.getJsonObjectFromCursorObjectForMmsText(cursor);
                    msg.put("address", util.getAddressesForMmsMessages(context, id));
                    msg.put("parts", util.getMmsPartsInJsonArray(context, id));
                    array.put(msg);

                    for (int j = 0; j < cursor.getColumnCount(); j++) {
                        msg.put(cursor.getColumnName(i), cursor.getString(cursor.getColumnIndexOrThrow(cursor.getColumnName(i))));
                    }

                    Log.i(TAG, msg.toString());

                    messages_received = messages_received || msg.getBoolean("received");

                    cursor.moveToNext();
                }
            }

            if (receivedDate > largestDateCounted) {
                largestDateCounted = receivedDate;
                UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_current_mms_counter), String.valueOf(largestDateCounted));
            }

            if (array != null && array.length() > 0) {
                JSONObject obj = new JSONObject();
                obj.put("messages", array);
                Log.i(TAG, Integer.toString(array.length()));
                Log.i(TAG, array.toString());

                String action = null;
                if (messages_received) {
                    action = "/message/received";
                } else {
                    action = "/message/send";
                }
                service.getDesktopWebserverService().sendMessageToServer(action, obj);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }
}
