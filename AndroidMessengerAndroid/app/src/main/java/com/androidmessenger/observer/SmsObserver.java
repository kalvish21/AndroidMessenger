package com.androidmessenger.observer;

import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.net.Uri;
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
        Cursor c = context.getContentResolver().query(Uri.parse(Constants.Sms + "/inbox"), null, null, null, null);
        c.moveToNext();

        if (c.getString(c.getColumnIndex("protocol")) != null) {
            // Received message
            try {
                Util util = new Util();
                Long largestDateCounted = Long.parseLong(UserPreferencesManager.getInstance().getValueFromPreferences(context, Constants.CURRENT_COUNTER, "0"));
                String _id = null;

                long receivedDate = 0;
                JSONArray array = new JSONArray();
                if (c.moveToFirst()) {
                    long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date")));
                    receivedDate = currentDate;

                    JSONObject obj = util.getJsonObjectFromCursorObjectForSmsText(c);
                    array.put(obj);

                    _id = obj.getString("id");
                }

                // Get all other pending messages for this user
                if (largestDateCounted != null && largestDateCounted > 0L) {
                    String filter = "creator != ? and date > ?";
                    String[] args = new String[]{context.getPackageName(), Long.toString(largestDateCounted)};
                    c = context.getContentResolver().query(Constants.Sms, null, filter, args, null);
                    int totalSMS = c.getCount();

                    if (c.moveToFirst()) {
                        for (int i = 0; i < totalSMS; i++) {
                            long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date")));
                            if (currentDate > largestDateCounted) {
                                largestDateCounted = currentDate;
                            }

                            String currentId = c.getString(c.getColumnIndexOrThrow("_id"));
                            if (!currentId.equals(_id)) {
                                JSONObject obj = util.getJsonObjectFromCursorObjectForSmsText(c);
                                array.put(obj);
                            }

                            c.moveToNext();
                        }
                    }
                }

                if (receivedDate > largestDateCounted) {
                    largestDateCounted = receivedDate;
                }
                UserPreferencesManager.getInstance().setStringInPreferences(context, Constants.CURRENT_COUNTER, String.valueOf(largestDateCounted));

                if (array != null && array.length() > 0) {
                    JSONObject obj = new JSONObject();
                    obj.put("messages", array);
                    try {
                        obj.put("action", "/message/received");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                    service.getAndroidWebSocket().sendJsonData(obj);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        c.close();
    }
}