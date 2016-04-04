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
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.telephony.PhoneNumberUtils;
import android.telephony.SmsManager;
import android.telephony.TelephonyManager;
import android.util.Log;

import com.androidmessenger.R;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.Constants;
import com.androidmessenger.util.UserPreferencesManager;
import com.androidmessenger.util.Util;

import org.apache.commons.lang3.StringUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Serializable;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.Collections;

/**
 * Created by Kalyan Vishnubhatla on 3/28/16.
 */
public class SmsMmsUriHandler implements Serializable {
    private final String TAG = SmsMmsUriHandler.class.getSimpleName();
    private static final long serialVersionUID = 292645201441507838L;
    private AndroidAppService service;
    private Context context;
    private Util util;

    private final String SEND = "send";

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
            args = new String[] {largestDate};
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
//        try {
//            c = contentResolver.query(Constants.Mms, null, filter, args, null);
//            for (int i = 0; i < c.getCount(); i++) {
//                c.moveToNext();
//                try {
//                    String id = c.getString(c.getColumnIndexOrThrow("_id"));
//
//                    // Keep track of the largest date
//                    long currentDate = Long.valueOf(c.getString(c.getColumnIndexOrThrow("date")));
//                    if (currentDate > largestDateCounted) {
//                        largestDateCounted = currentDate;
//                    }
//
//                    JSONObject msg = util.getJsonObjectFromCursorObjectForMmsText(c);
//                    msg.put("address", getAddressesForMmsMessages(id));
//                    msg.put("parts", getMmsPartsInJsonArray(id));
//                    array.put(msg);
//
//                } catch (JSONException j) {
//                    j.printStackTrace();
//                }
//            }
//        } catch (Exception e) {
//            e.printStackTrace();
//
//        } finally {
//            UserPreferencesManager.getInstance().setStringInPreferences(context, Constants.CURRENT_COUNTER, String.valueOf(largestDateCounted));
//            c.close();
//        }
        return array;
    }

    // MMS messages can have multiple parties involved. This will retrieve all of them except for the current user
    public String getAddressesForMmsMessages(String msgId) {
        String uriStr = MessageFormat.format(Constants.Mms + "/{0}/addr", msgId);
        Uri uriAddress = Uri.parse(uriStr);
        Cursor cAdd = context.getContentResolver().query(uriAddress, null, "msg_id=" + msgId, null, null);
        ArrayList<String> addressList = new ArrayList<>();

        // Get the current devices phone number
        String currentPhoneNumber = UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_current_phonenumber));
        if (currentPhoneNumber == null) {
            // Get the current phone number
            TelephonyManager tMgr = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (tMgr.getLine1Number() != null) {
                UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_current_phonenumber), tMgr.getLine1Number());
                currentPhoneNumber = tMgr.getLine1Number();
            }

            // Check again to make sure
            if (currentPhoneNumber == null) {
                currentPhoneNumber = "";
            }
        }

        if (cAdd.moveToFirst()) {
            do {
                String number = cAdd.getString(cAdd.getColumnIndex("address"));
                if (number != null && !PhoneNumberUtils.compare(number, currentPhoneNumber)) {
                    try {
                        Long.parseLong(number.replace("-", ""));
                        if (!number.contains(currentPhoneNumber)) {
                            addressList.add(number);
                        }
                    } catch (NumberFormatException nfe) {
                        if (addressList.size() == 0 && !number.contains(currentPhoneNumber)) {
                            addressList.add(number);
                        }
                    }
                }
            } while (cAdd.moveToNext());
            Collections.sort(addressList);
        }
        if (cAdd != null) {
            cAdd.close();
        }

        if (addressList.size() > 0) {
            String listString = "";
            for (String s : addressList) {
                listString += s + ",";
            }
            return listString.substring(0, listString.length() - 1);
        }
        return "";
    }

    // MMS messages have multiple "parts" (images, video, text, etc). This will grab each part and return an array
    public JSONArray getMmsPartsInJsonArray(String msgId) {
        ContentResolver contentResolver = context.getContentResolver();
        Cursor c = contentResolver.query(Constants.MmsPart, null, "mid=" + msgId, null, null);
        JSONArray array = new JSONArray();

        try {
            if (c.moveToFirst()) {
                do {
                    String mid = c.getString(c.getColumnIndex("mid"));
                    String type = c.getString(c.getColumnIndex("ct"));

                    if (type.equals("application/smil")) {
                        // We can ignore this type since we don't need it
                        continue;
                    }

                    JSONObject msg = new JSONObject();
                    msg.put("mid", mid);
                    msg.put("part_id", c.getString(c.getColumnIndex("_id")));
                    msg.put("type", type);

                    switch (type) {
                        case "text/plain": {
                            // MMS is just plain text, so get the text
                            String data = c.getString(c.getColumnIndex("_data"));
                            String body;
                            if (data != null) {
                                body = getMmsText(msgId);
                            } else {
                                body = c.getString(c.getColumnIndex("text"));
                            }
                            msg.put("msg", body);
                            break;
                        }

                        default: {
                            break;
                        }
                    }
                    array.put(msg);
                } while (c.moveToNext());
            }
        } catch (JSONException j) {
            j.printStackTrace();
        } finally {
            c.close();
        }
        return array;
    }

    // MMS messages have text parts that can be parsed.
    public String getMmsText(String id) {
        Uri partURI = Uri.parse(Constants.MmsPart + "/" + id);
        InputStream is = null;
        StringBuilder sb = new StringBuilder();
        try {
            is = context.getContentResolver().openInputStream(partURI);
            if (is != null) {
                InputStreamReader isr = new InputStreamReader(is, "UTF-8");
                BufferedReader reader = new BufferedReader(isr);
                String temp = reader.readLine();
                while (temp != null) {
                    sb.append(temp);
                    temp = reader.readLine();
                }
            }
        } catch (IOException e) {
        } finally {
            if (is != null) {
                try {
                    is.close();
                } catch (IOException e) {
                }
            }
        }
        return sb.toString();
    }

    // Used to get a Bitmap image from MMS messages, if needed
    public Bitmap getMmsImage(String part_id) {
        Uri partURI = Uri.parse(Constants.MmsPart + "/" + part_id);
        InputStream is = null;
        Bitmap bitmap = null;
        try {
            is = context.getContentResolver().openInputStream(partURI);
            bitmap = BitmapFactory.decodeStream(is);
        } catch (IOException e) {
        } finally {
            if (is != null) {
                try {
                    is.close();
                } catch (IOException e) {
                }
            }
        }

        return bitmap;
    }

    // Sending an SMS
    public void sendSms(final String phoneNumber, final String message, final String uuid) {
        Intent sentIntent = new Intent(SEND);
        PendingIntent sendingPendingIntent = PendingIntent.getBroadcast(context.getApplicationContext(), 0, sentIntent, PendingIntent.FLAG_UPDATE_CURRENT);
        BroadcastReceiver receiver = new BroadcastReceiver() {
            public void onReceive(Context context, Intent intent) {
                switch (getResultCode()) {
                    case Activity.RESULT_OK: {
                        Bundle bundle = intent.getExtras();
                        String smsUri = bundle.getString("uri");

                        // Multipart text messages will have multiple callbacks but only one will have a uri
                        if (smsUri != null) {
                            smsMmsCallback(smsUri, uuid);
                        }
                    }
                    break;

                    default: {
                        Bundle bundle = intent.getExtras();
                        String smsUri = bundle.getString("uri");

                        // Depending on the type of failure we may not have a uri
                        if (smsUri != null) {
                            smsMmsCallback(smsUri, uuid);
                        }
                    }
                    break;
                }
                context.unregisterReceiver(this);
            }

            private void smsMmsCallback(String smsUri, String uuid) {
                Cursor c = null;
                try {
                    c = context.getContentResolver().query(Uri.parse(smsUri), null, null, null, null);
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

        };
        context.registerReceiver(receiver, new IntentFilter(SEND));

        SmsManager smsManager = SmsManager.getDefault();

        // SMS messages can only be 160 characters. If it's greater we need to send a multi-part message
        ArrayList<String> parts = smsManager.divideMessage(message);
        if (parts.size() > 1) {
            ArrayList<PendingIntent> sendingPendingIntents = new ArrayList<>();
            for (String s:parts) {
                sendingPendingIntents.add(sendingPendingIntent);
            }
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, sendingPendingIntents, null);
        } else {
            smsManager.sendTextMessage(phoneNumber, null, message, sendingPendingIntent, null);
        }
    }
}
