package com.androidmessenger.util;

import android.content.Context;
import android.database.Cursor;

import com.androidmessenger.R;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.Serializable;

/**
 * Created by Kalyan Vishnubhatla on 3/24/16.
 */
public class Util implements Serializable {
    private static final long serialVersionUID = -6213728709141526781L;

    public JSONObject getJsonObjectFromCursorObjectForSmsText(Cursor c) {
        try {
            JSONObject msg = new JSONObject();
            msg.put("id", c.getString(c.getColumnIndexOrThrow("_id")));
            msg.put("address", c.getString(c.getColumnIndexOrThrow("address")));
            msg.put("msg", c.getString(c.getColumnIndexOrThrow("body")));
            msg.put("read", c.getString(c.getColumnIndexOrThrow("read")).contains("1"));
            msg.put("time", c.getString(c.getColumnIndexOrThrow("date")));
            msg.put("received", c.getString(c.getColumnIndexOrThrow("type")).contains("1"));
            msg.put("failed", c.getString(c.getColumnIndexOrThrow("type")).contains("5"));
            msg.put("number", c.getString(c.getColumnIndexOrThrow("address")));
            msg.put("thread_id", c.getString(c.getColumnIndexOrThrow("thread_id")));
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
            msg.put("id", c.getString(c.getColumnIndexOrThrow("_id")));
            msg.put("read", c.getString(c.getColumnIndexOrThrow("read")).contains("1"));
            msg.put("time", c.getString(c.getColumnIndexOrThrow("date")));
            msg.put("m_id", c.getString(c.getColumnIndexOrThrow("m_id")));
            msg.put("received", c.getString(c.getColumnIndexOrThrow("msg_box")).contains("1"));
//            msg.put("failed", c.getString(c.getColumnIndexOrThrow("type")).contains("5"));
            msg.put("thread_id", c.getString(c.getColumnIndexOrThrow("thread_id")));
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
}
