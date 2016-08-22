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

        Long largestDateCounted = Long.parseLong(UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_current_counter), "0")) / 1000;
        String filter = "creator != ? and date > ?";
        String[] args = new String[]{context.getPackageName(), Long.toString(largestDateCounted)};

        Cursor c = null;
        try {
            c = context.getContentResolver().query(Uris.Mms, null, filter, args, null);
            Util util = new Util();
            long receivedDate = 0;
            JSONArray array = new JSONArray();
            Map<String, String> map = new HashMap<>();
            boolean messages_received = false;

            if (c.moveToFirst()) {
                for (int i = 0; i < c.getCount(); i++) {

                    // TODO: Ignore draft and outbox messages for now
                    String msgBoxValue = c.getString(c.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_BOX));
                    if (!(msgBoxValue.contains(String.valueOf(Telephony.Mms.MESSAGE_BOX_INBOX)) ||
                            msgBoxValue.contains(String.valueOf(Telephony.Mms.MESSAGE_BOX_SENT)))) {
                        continue;
                    }

                    String id = c.getString(c.getColumnIndexOrThrow(Telephony.Mms._ID));
                    if (map.get(id) != null) {
                        continue;
                    }
                    map.put(id, id);

                    // Keep track of the largest date
                    long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow(Telephony.Mms.DATE)));
                    if (currentDate > largestDateCounted) {
                        receivedDate = currentDate;
                    }

                    JSONObject msg = util.getJsonObjectFromCursorObjectForMmsText(c);
                    msg.put("address", util.getAddressesForMmsMessages(context, id));
                    msg.put("parts", util.getMmsPartsInJsonArray(context, id));
                    array.put(msg);

                    messages_received = messages_received || msg.getBoolean("received");

                    c.moveToNext();
                }
            }

            if (receivedDate > largestDateCounted*1000) {
                largestDateCounted = receivedDate;
                UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_current_counter), String.valueOf(largestDateCounted * 1000));
            }

            if (array != null && array.length() > 0) {
                JSONObject obj = new JSONObject();
                obj.put("messages", array);
                Log.i(TAG, Integer.toString(array.length()));
                Log.i(TAG, array.toString());
                try {
                    if (messages_received) {
                        obj.put("action", "/message/received");
                    } else {
                        obj.put("action", "/message/send");
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                service.getAndroidWebSocket().sendJsonData(obj);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (c != null) {
                c.close();
            }
        }
    }
}
