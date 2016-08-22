package com.androidmessenger.util;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.provider.Telephony;
import android.telephony.PhoneNumberUtils;
import android.telephony.TelephonyManager;

import com.androidmessenger.R;

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
 * Created by Kalyan Vishnubhatla on 3/24/16.
 */
public class Util implements Serializable {
    private static final long serialVersionUID = -6213728709141526781L;

    public JSONObject getJsonObjectFromCursorObjectForSmsText(Cursor c) {
        try {
            JSONObject msg = new JSONObject();
            msg.put("id", c.getString(c.getColumnIndexOrThrow(Telephony.Sms._ID)));
            msg.put("address", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)));
            msg.put("msg", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.BODY)));
            msg.put("read", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.READ)).contains("1"));
            msg.put("time", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.DATE)));
            msg.put("received", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.TYPE)).contains("1"));
            msg.put("failed", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.TYPE)).contains("5"));
            msg.put("number", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)));
            msg.put("thread_id", c.getString(c.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)));
            msg.put("type", "sms");

            return msg;

        } catch (JSONException j) {
            j.printStackTrace();
        }
        return null;
    }

    public JSONObject getJsonObjectFromCursorObjectForMmsText(Cursor c) {
        try {
            JSONObject msg = new JSONObject();
            msg.put("id", c.getString(c.getColumnIndexOrThrow(Telephony.Mms._ID)));
            msg.put("read", c.getString(c.getColumnIndexOrThrow(Telephony.Mms.READ)).contains("1"));
            msg.put("time", c.getString(c.getColumnIndexOrThrow(Telephony.Mms.DATE)));
            msg.put("m_id", c.getString(c.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_ID)));
            msg.put("received", c.getString(c.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_BOX)).contains("1"));
            msg.put(Telephony.Mms.MESSAGE_BOX, c.getString(c.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_BOX)));
            msg.put("thread_id", c.getString(c.getColumnIndexOrThrow(Telephony.Mms.THREAD_ID)));
            msg.put("type", "mms");

            return msg;

        } catch (JSONException j) {
            j.printStackTrace();
        }
        return null;
    }

    public boolean verifyUUID(Context context, String uuid) {
        if (uuid.equals("testing")) {
            return true;
        }
        String currentUUID = UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_device_uuid));
        return currentUUID != null && uuid != null && currentUUID.equals(uuid);
    }

    // MMS messages can have multiple parties involved. This will retrieve all of them except for the current user
    public String getAddressesForMmsMessages(final Context context, String msgId) {
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
    public JSONArray getMmsPartsInJsonArray(final Context context, String msgId) {
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
                                body = getMmsText(context, msgId);
                            } else {
                                body = c.getString(c.getColumnIndex("text"));
                            }
                            msg.put("msg", body);
                            break;
                        }

                        case "image/jpeg":
                        case "image/jpg":
                        case "image/png":
                        case "image/gif":
                        case "image/bmp": {
                            // We have all information required
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
    public String getMmsText(final Context context, String id) {
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
    public Bitmap getMmsImage(final Context context, String part_id) {
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
}
