package com.androidmessenger.service;

import android.app.Service;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.database.Cursor;
import android.os.Binder;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.support.annotation.Nullable;
import android.widget.Toast;

import com.androidmessenger.connections.WebServer;
import com.androidmessenger.connections.WebSocket;
import com.androidmessenger.util.Constants;
import com.androidmessenger.util.UserPreferencesManager;
import com.androidmessenger.util.Util;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Created by Kalyan Vishnubhatla on 3/24/16.
 */
public class AndroidAppService extends Service {
    public static final String TAG = AndroidAppService.class.getSimpleName();
    private Looper mServiceLooper;
    public static ServiceHandler mServiceHandler;
    private WebSocket webSocket;
    private WebServer webServer;

    public AndroidAppService() {
        super();
    }

    public WebSocket getAndroidWebSocket() {
        return webSocket;
    }

    @Override
    public void onCreate() {
        // Start up the thread running the service.  Note that we create a
        // separate thread because the service normally runs in the process's
        // main thread, which we don't want to block.  We also make it
        // background priority so CPU-intensive work will not disrupt our UI.
        HandlerThread thread = new HandlerThread("ServiceStartArguments");
        thread.start();

        // Start websocket and HTTP server
        startServers();

        Intent intent = new Intent(this, AndroidAppService.class);
        bindService(intent, m_serviceConnection, BIND_AUTO_CREATE);

        // Get the HandlerThread's Looper and use it for our Handler
        mServiceLooper = thread.getLooper();
        mServiceHandler = new ServiceHandler(mServiceLooper, getBaseContext());
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // If we get killed, after returning from here, restart
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopServers();
    }

    public void startServers() {
        Toast.makeText(this, "Starting servers ...", Toast.LENGTH_LONG).show();
        try {
            webSocket = new WebSocket(this);
            webSocket.start();
        } catch (IllegalStateException e) {
            // Already started
            e.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }

        try {
            webServer = new WebServer(this);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void stopServers() {
        Toast.makeText(this, "Stopping servers ...", Toast.LENGTH_LONG).show();
        try {
            if (webSocket != null) {
                webSocket.closeAllConnectionsAndStop();
                webSocket = null;
            }

            if (webServer != null) {
                webServer.stop();
                webServer = null;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    AndroidAppService m_service;
    private ServiceConnection m_serviceConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            m_service = ((AndroidAppService.MyBinder)service).getService();
        }

        public void onServiceDisconnected(ComponentName className) {
            m_service = null;
        }
    };

    public class MyBinder extends Binder {
        public AndroidAppService getService() {
            return AndroidAppService.this;
        }
    }

    // Handler that receives messages from the thread
    public class ServiceHandler extends Handler {
        Context context;
        public ServiceHandler(Looper looper, Context context) {
            super(looper);
            this.context = context;
        }

        public void handleMessage(Message msg) {
            Bundle bundle = msg.getData();

            String type = bundle.getString("type");
            switch (type) {
                case "wifi": {
                    // Wifi state was changed
//                    Boolean wifi = bundle.getBoolean("wifi");
//                    if (wifi) {
//                        AndroidAppService.this.startServers();
//                    } else {
//                        AndroidAppService.this.stopServers();
//                    }
                    break;
                }

                case "sms": {
                    String number = bundle.getString("phoneNumber");
                    Long time = bundle.getLong("time");
                    String message = bundle.getString("message");
                    smsWasReceived(number, time, message);
                    break;
                }
            }
        }

        private void smsWasReceived(String number, Long time, String message) {
            Cursor c = null;
            try {
                Util util = new Util();
                Long largestDateCounted = Long.parseLong(UserPreferencesManager.getInstance().getValueFromPreferences(context, Constants.CURRENT_COUNTER, "0"));
                String _id = null;

                String filter = String.format("body='%s' AND date=%s AND address='%s'", message, Long.toString(time), number);
                c = context.getContentResolver().query(Constants.Sms, null, filter, null, null);

                // This should not happen, but we were unable to find the message that was received in the SMS database
                if (c.getCount() == 0) {
                    return;
                }

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
                    filter = "date > ?";
                    String[] args = new String[] {Long.toString(largestDateCounted)};
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
                    webSocket.sendJsonData(obj);
                }
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                if (c!= null) {
                    c.close();
                }
            }
        }
    }
}
