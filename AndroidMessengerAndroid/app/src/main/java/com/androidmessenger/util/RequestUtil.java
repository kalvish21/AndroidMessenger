package com.androidmessenger.util;

import android.content.Context;

import com.loopj.android.http.AsyncHttpClient;
import com.loopj.android.http.AsyncHttpResponseHandler;
import com.loopj.android.http.RequestParams;

import org.json.JSONObject;

import java.nio.charset.StandardCharsets;
import java.nio.charset.UnsupportedCharsetException;

import cz.msebera.android.httpclient.entity.StringEntity;
import cz.msebera.android.httpclient.message.BasicHeader;
import cz.msebera.android.httpclient.protocol.HTTP;

/**
 * Created by Kalyan Vishnubhatla on 8/27/16.
 */
public class RequestUtil {
    public static final String BASE_URL = "BASE_URL";
    private static AsyncHttpClient client = new AsyncHttpClient();

    public static void get(Context context, String url, RequestParams params, AsyncHttpResponseHandler responseHandler) {
        client.get(getAbsoluteUrl(context, url), params, responseHandler);
    }

    public static void post(Context context, String url, RequestParams params, AsyncHttpResponseHandler responseHandler) {
        client.post(getAbsoluteUrl(context, url), params, responseHandler);
    }

    public static void postJson(Context context, String url, JSONObject obj, AsyncHttpResponseHandler responseHandler) {
        StringEntity se = getStringEntityFromJsonObject(obj);
        client.post(null, getAbsoluteUrl(context, url), se, se.getContentType().getValue(), responseHandler);
    }

    public static StringEntity getStringEntityFromJsonObject(JSONObject obj) {
        try {
            StringEntity se = new StringEntity(obj.toString(), StandardCharsets.UTF_8);
            se.setContentType("application/json;charset=UTF-8");
            se.setContentEncoding(new BasicHeader(HTTP.CONTENT_TYPE, "application/json"));
            return se;

        } catch (UnsupportedCharsetException e) {
            e.printStackTrace();
        }
        return null;
    }

    private static String getAbsoluteUrl(Context context, String relativeUrl) {
        String baseUrl = UserPreferencesManager.getInstance().getValueFromPreferences(context, BASE_URL);
        return baseUrl + relativeUrl;
    }
}
