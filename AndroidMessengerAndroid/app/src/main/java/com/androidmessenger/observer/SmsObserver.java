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

/**
 * Created by Kalyan Vishnubhatla on 4/1/16.
 */
public class SmsObserver extends ContentObserver {
    private static final String TAG = SmsObserver.class.getSimpleName();
    private Context context;
    private AndroidAppService service;

    public SmsObserver(Handler handler, AndroidAppService service) {
        super(handler);
        this.context = service.getBaseContext();
        this.service = service;
    }

    @Override
    public void onChange(boolean selfChange) {
        super.onChange(selfChange);

        Long largestDateCounted = Long.parseLong(UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_current_counter), "0"));
        String[] args = new String[]{context.getPackageName(), Long.toString(largestDateCounted)};
        Cursor cursor = context.getContentResolver().query(Uris.Sms, null, "creator != ? and date > ?", args, null);

        try {
            Util util = new Util();
            long receivedDate = 0;
            JSONArray array = new JSONArray();
            boolean messages_received = false;

            if (cursor.moveToFirst()) {
                for (int i = 0; i < cursor.getCount(); i++) {

                    // TODO: Ignore draft and outbox messages for now
                    String msgBoxType = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE));
                    if (msgBoxType.contains(String.valueOf(Telephony.Sms.MESSAGE_TYPE_OUTBOX)) ||
                            msgBoxType.contains(String.valueOf(Telephony.Sms.MESSAGE_TYPE_DRAFT))) {
                        continue;
                    }

                    // Update the largest counter
                    long currentDate = Long.valueOf(cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)));
                    if (currentDate > largestDateCounted) {
                        receivedDate = currentDate;
                    }

                    // Create the JSON object from the cursor
                    JSONObject obj = util.getJsonObjectFromCursorObjectForSmsText(cursor);
                    array.put(obj);

                    // See if we have any received messages, URL needs to be updated for it
                    messages_received = messages_received || obj.getBoolean("received");

                    cursor.moveToNext();
                }
            }

            if (receivedDate > largestDateCounted) {
                largestDateCounted = receivedDate;
                UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_current_counter), String.valueOf(largestDateCounted));
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
            cursor.close();
        }
    }
}