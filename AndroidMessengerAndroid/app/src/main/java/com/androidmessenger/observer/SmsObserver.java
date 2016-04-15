package com.androidmessenger.observer;

import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.os.Handler;
import android.util.Log;

import com.androidmessenger.R;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.Constants;
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
        String filter = "creator != ? and date > ?";
        String[] args = new String[]{context.getPackageName(), Long.toString(largestDateCounted)};
        Cursor c = context.getContentResolver().query(Constants.Sms, null, filter, args, null);

        try {
            Util util = new Util();
            long receivedDate = 0;
            JSONArray array = new JSONArray();
            boolean messages_received = false;

            if (c.moveToFirst()) {
                for (int i = 0; i < c.getCount(); i++) {

                    // TODO: Ignore draft and outbox messages for now
                    if (c.getString(c.getColumnIndexOrThrow("type")).contains("3") || c.getString(c.getColumnIndexOrThrow("type")).contains("4")) {
                        continue;
                    }

                    // Update the largest counter
                    long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date")));
                    if (currentDate > largestDateCounted) {
                        receivedDate = currentDate;
                    }

                    // Create the JSON object from the cursor
                    JSONObject obj = util.getJsonObjectFromCursorObjectForSmsText(c);
                    array.put(obj);

                    // See if we have any received messages, URL needs to be updated for it
                    messages_received = messages_received || obj.getBoolean("received");

                    c.moveToNext();
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
            c.close();
        }
    }
}