package com.androidmessenger.observer;

import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.os.Handler;

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
    private Handler handler = null;
    private Context context;
    private AndroidAppService service;

    public SmsObserver(Handler handler, AndroidAppService service) {
        super(handler);
        this.handler = handler;
        this.context = service.getBaseContext();
        this.service = service;
    }

    @Override
    public void onChange(boolean selfChange) {
        super.onChange(selfChange);

        Long largestDateCounted = Long.parseLong(UserPreferencesManager.getInstance().getValueFromPreferences(context, Constants.CURRENT_COUNTER, "0"));
        String filter = "creator != ? and date > ?";
        String[] args = new String[]{context.getPackageName(), Long.toString(largestDateCounted)};
        Cursor c = context.getContentResolver().query(Constants.Sms, null, filter, args, null);

        try {
            Util util = new Util();
            long receivedDate = 0;
            JSONArray array = new JSONArray();
            boolean messages_received = false;

            if (c.moveToFirst()) {
                int totalSMS = c.getCount();
                for (int i = 0; i < totalSMS; i++) {
                    long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date")));
                    if (currentDate > largestDateCounted) {
                        receivedDate = currentDate;
                    }

                    JSONObject obj = util.getJsonObjectFromCursorObjectForSmsText(c);
                    array.put(obj);

                    messages_received = messages_received || obj.getBoolean("received");
                    c.moveToNext();
                }
            }

            if (receivedDate > largestDateCounted) {
                largestDateCounted = receivedDate;
                UserPreferencesManager.getInstance().setStringInPreferences(context, Constants.CURRENT_COUNTER, String.valueOf(largestDateCounted));
            }

            if (array != null && array.length() > 0) {
                JSONObject obj = new JSONObject();
                obj.put("messages", array);
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