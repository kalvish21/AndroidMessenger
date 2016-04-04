package com.androidmessenger.service;

import android.app.Service;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
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
import com.androidmessenger.observer.SmsObserver;
import com.androidmessenger.util.Constants;

/**
 * Created by Kalyan Vishnubhatla on 3/24/16.
 */
public class AndroidAppService extends Service {
    public static final String TAG = AndroidAppService.class.getSimpleName();
    private Looper mServiceLooper;
    public static ServiceHandler mServiceHandler;

    private WebSocket webSocket;
    private WebServer webServer;
    private SmsObserver content;

    public AndroidAppService() {
        super();
    }

    @Override
    public void onCreate() {
        HandlerThread thread = new HandlerThread("ServiceStartArguments");
        thread.start();

        // Start servers
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

    public WebSocket getAndroidWebSocket() {
        return webSocket;
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
            webServer.start();
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Add observer
        content = new SmsObserver(new Handler(), this);
        getContentResolver().registerContentObserver(Constants.Sms, true, content);
    }

    public void stopServers() {
        Toast.makeText(this, "Stopping servers ...", Toast.LENGTH_LONG).show();
        try {
            // Shut down websocket
            if (webSocket != null) {
                webSocket.closeAllConnectionsAndStop();
                webSocket = null;
            }

            // Shutdown webserver
            if (webServer != null) {
                webServer.stop();
                webServer = null;
            }

            // Remove observers
            getContentResolver().unregisterContentObserver(content);
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
            }
        }
    }
}
