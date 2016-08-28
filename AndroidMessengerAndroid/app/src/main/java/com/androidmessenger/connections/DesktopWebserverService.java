package com.androidmessenger.connections;

import android.content.Context;

import com.androidmessenger.util.RequestUtil;
import com.androidmessenger.util.UserPreferencesManager;
import com.loopj.android.http.AsyncHttpResponseHandler;

import org.json.JSONObject;

import java.io.Serializable;

import cz.msebera.android.httpclient.Header;

/**
 * Created by Kalyan Vishnubhatla on 8/25/16.
 */
public class DesktopWebserverService implements Serializable {
    private static final long serialVersionUID = -6745486654622948300L;
    private Context context;
    private final String PORT_NUMBER = "9192";

    public DesktopWebserverService(Context context) {
        this.context = context;

        UserPreferencesManager.getInstance().setStringInPreferences(context, RequestUtil.BASE_URL, "http://10.0.0.62:9192/");
    }

    public void sendMessageToServer(String action, JSONObject object) {
        switch (action) {
            case "/message/send": {
                RequestUtil.postJson(context, action, object, new AsyncHttpResponseHandler() {
                    @Override
                    public void onSuccess(int statusCode, Header[] headers, byte[] responseBody) {

                    }

                    @Override
                    public void onFailure(int statusCode, Header[] headers, byte[] responseBody, Throwable error) {

                    }
                });
                break;
            }

            case "/message/received": {
                RequestUtil.postJson(context, action, object, new AsyncHttpResponseHandler() {
                    @Override
                    public void onSuccess(int statusCode, Header[] headers, byte[] responseBody) {

                    }

                    @Override
                    public void onFailure(int statusCode, Header[] headers, byte[] responseBody, Throwable error) {

                    }
                });
                break;
            }
        }
    }
}
