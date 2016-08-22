package com.androidmessenger.urihandler;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.telephony.SmsManager;
import android.util.Log;

import com.androidmessenger.R;
import com.androidmessenger.observer.SendingSmsObserver;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.Constants;
import com.androidmessenger.util.UserPreferencesManager;
import com.androidmessenger.util.Util;

import org.apache.commons.lang3.StringUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * Created by Kalyan Vishnubhatla on 3/28/16.
 */
public class SmsMmsUriHandler implements Serializable, SendingSmsObserver.OnSmsSentListener {
    private final String TAG = SmsMmsUriHandler.class.getSimpleName();
    private static final long serialVersionUID = 292645201441507838L;
    private AndroidAppService service;
    private Context context;
    private Util util;

    public SmsMmsUriHandler(AndroidAppService service) {
        this.service = service;
        this.context = service.getBaseContext();
        this.util = new Util();
    }

    public void markSmsMessageAsRead(String threadId, String[] ids) {
        String filter = String.format("thread_id=%s AND _id IN (%s)", threadId, StringUtils.join(ids, ", "));
        Cursor cursor = context.getContentResolver().query(Constants.Sms, null, filter, null, null);
        try {
            while (cursor.moveToNext()) {
                if ((cursor.getInt(cursor.getColumnIndex("read")) == 0)) {
                    String SmsMessageId = cursor.getString(cursor.getColumnIndex("_id"));
                    ContentValues values = new ContentValues();
                    values.put("read", true);
                    context.getContentResolver().update(Constants.Sms, values, "_id=" + SmsMessageId, null);
                }
            }
        } catch (Exception e) {
            Log.e("Mark Read", "Error in Read: " + e.toString());
        }
    }

    public JSONArray getLatestSmsMmsMessagesFromDate(String largestDate) {
        // Keep track of the largest date from the desktop
        Long largestDateCounted = largestDate == null ? 0 : Long.parseLong(largestDate);

        // If the user passed in a date, filter for dates greater than or equal to what is passed in
        String filter = null;
        String[] args = null;
        if (largestDate != null) {
            filter = "date >= ?";
            args = new String[]{largestDate};
        }

        ContentResolver contentResolver = context.getContentResolver();
        JSONArray array = new JSONArray();

        // Get the SMS messages
        Cursor c = contentResolver.query(Constants.Sms, null, filter, args, null);
        try {
            for (int i = 0; i < c.getCount(); i++) {
                c.moveToNext();

                /*
                    Message Types
                    MESSAGE_TYPE_ALL    = 0;
                    MESSAGE_TYPE_INBOX  = 1;
                    MESSAGE_TYPE_SENT   = 2;
                    MESSAGE_TYPE_DRAFT  = 3;
                    MESSAGE_TYPE_OUTBOX = 4;
                    MESSAGE_TYPE_FAILED = 5; // for failed outgoing messages
                    MESSAGE_TYPE_QUEUED = 6; // for messages to send later
                */

                // TODO: Ignore draft and outbox messages for now
                if (c.getString(c.getColumnIndexOrThrow("type")).contains("3") || c.getString(c.getColumnIndexOrThrow("type")).contains("4")) {
                    continue;
                }

                // Keep track of the largest date
                long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date")));
                if (currentDate > largestDateCounted) {
                    largestDateCounted = currentDate;
                }

                JSONObject msg = util.getJsonObjectFromCursorObjectForSmsText(c);
                array.put(msg);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_current_counter), String.valueOf(largestDateCounted));
            c.close();
        }


        // Get the MMS messages
        try {
            c = contentResolver.query(Constants.Mms, null, filter, args, null);
            for (int i = 0; i < c.getCount(); i++) {
                c.moveToNext();
                try {
                    String id = c.getString(c.getColumnIndexOrThrow("_id"));

                    // Keep track of the largest date
                    long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date"))) * 1000;
                    if (currentDate > largestDateCounted) {
                        largestDateCounted = currentDate;
                    }

                    JSONObject msg = util.getJsonObjectFromCursorObjectForMmsText(c);
                    msg.put("address", util.getAddressesForMmsMessages(context, id));
                    msg.put("parts", util.getMmsPartsInJsonArray(context, id));
                    array.put(msg);

                } catch (JSONException j) {
                    j.printStackTrace();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();

        } finally {
            UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_current_counter), String.valueOf(largestDateCounted));
            c.close();
        }
        return array;
    }

    // Sending an SMS
    public void sendSms(final String phoneNumber, final String message, final String uuid) {
        SmsManager smsManager = SmsManager.getDefault();

        // SMS messages can only be 160 characters. If it's greater we need to send a multi-part message
        ArrayList<String> parts = smsManager.divideMessage(message);
        if (parts.size() > 1) {
            new Handler(context.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    new SendingSmsObserver(SmsMmsUriHandler.this, context, phoneNumber, message, uuid).start();
                }
            });
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null);
        } else {
            Intent sentIntent = new Intent(uuid);
            PendingIntent sendingPendingIntent = PendingIntent.getBroadcast(context.getApplicationContext(), 0, sentIntent, PendingIntent.FLAG_UPDATE_CURRENT);
            BroadcastReceiver receiver = new BroadcastReceiver() {
                public void onReceive(Context context, Intent intent) {
                    switch (getResultCode()) {
                        case Activity.RESULT_OK: {
                            Bundle bundle = intent.getExtras();
                            Map<String, Object> map = new HashMap<>();
                            for (String key : bundle.keySet()) {
                                map.put(key, bundle.get(key));
                            }
                            String smsUri = bundle.getString("uri");
                            Log.i(TAG, smsUri);

                            onSmsSent(Uri.parse(smsUri), uuid);
                        }
                        break;

                        default: {
                            Bundle bundle = intent.getExtras();
                            String smsUri = bundle.getString("uri");

                            // Depending on the type of failure we may not have a uri
                            if (smsUri != null) {
                                onSmsSent(Uri.parse(smsUri), uuid);
                            }
                        }
                        break;
                    }
                    context.unregisterReceiver(this);
                }
            };
            context.registerReceiver(receiver, new IntentFilter(uuid));

            smsManager.sendTextMessage(phoneNumber, null, message, sendingPendingIntent, null);
        }
    }

    public void onSmsSent(Uri uri, String uuid) {
        Cursor c = null;
        try {
            c = context.getContentResolver().query(uri, null, null, null, null);
            JSONObject msg = null;
            if (c.moveToFirst()) {
                msg = util.getJsonObjectFromCursorObjectForSmsText(c);
            }

            if (msg != null) {
                try {
                    msg.put("action", "/message/send");
                    msg.put("uuid", uuid);
                } catch (Exception e) {
                    e.printStackTrace();
                }
                service.getAndroidWebSocket().sendJsonData(msg);
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
