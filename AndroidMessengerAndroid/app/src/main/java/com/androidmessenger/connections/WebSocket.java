package com.androidmessenger.connections;

import android.Manifest;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Handler;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.widget.Toast;

import com.androidmessenger.R;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.util.UserPreferencesManager;
import com.androidmessenger.util.Util;

import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.InetSocketAddress;
import java.net.UnknownHostException;

/**
 * Created by Kalyan Vishnubhatla on 3/23/16.
 */
public class WebSocket extends WebSocketServer {
    private static final String TAG = WebSocket.class.getSimpleName();
    public static final int PORT_NUMBER = 5555;
    private Context context;
    private Util util;

    public WebSocket(AndroidAppService service) throws UnknownHostException {
        super(new InetSocketAddress(PORT_NUMBER));
        this.context = service.getBaseContext();
        this.util = new Util();
    }

    public void sendJsonData(JSONObject obj) {
        try {
            if (connections().size() == 0) {
                Log.e(TAG, "No websocket connection!");
            }
            Log.i(TAG, obj.toString());
            for (org.java_websocket.WebSocket conn: connections()) {
                conn.send(obj.toString());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void closeAllConnections() {
        if (this.connections().size() > 0) {
            for (org.java_websocket.WebSocket sock:connections()) {
                sock.close();
            }
        }
    }

    public void closeAllConnectionsAndStop() {
        try {
            closeAllConnections();
            stop();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onOpen(org.java_websocket.WebSocket conn, ClientHandshake handshake) {
        Log.i(TAG, conn.getRemoteSocketAddress().getHostName());

        String[] values = handshake.getResourceDescriptor().split("/");
        if (values.length < 2) {
            conn.close();
        }

        String uuid = values[1];
        String deviceName = values[2];
        String currentUUID = UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_device_uuid));
        if (currentUUID != null && !util.verifyUUID(context, uuid)) {
            new Handler(context.getMainLooper()).post(new Runnable() {
                public void run() {
                    Toast.makeText(context, "New device tried to connect! Device ID does not match.", Toast.LENGTH_SHORT).show();
                }
            });
            conn.close();
            return;
        } else {
            UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_device_uuid), uuid);
            UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_device_name), deviceName);

            try {
                JSONObject returnObj = new JSONObject();
                returnObj.put("action", "/new_device");
                sendJsonData(returnObj);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    @Override
    public void onClose(org.java_websocket.WebSocket conn, int code, String reason, boolean remote) {
        Log.i(TAG, conn.toString());
    }

    @Override
    public void onMessage(org.java_websocket.WebSocket conn, String message) {
        Log.i(TAG, conn.toString());
        Log.i(TAG, message);

        try {
            JSONObject obj = new JSONObject(message);
            String action = obj.getString("action");

            if (action != null && action.length() > 0) {
                switch (action) {
                    case "/phone_call": {
                        String uuid = obj.getString("uid");
                        if (!util.verifyUUID(context, uuid)) {
                            conn.close();
                            return;
                        }

                        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                            // Permission not granted
                            JSONObject returnObj = new JSONObject();
                            returnObj.put("permission", "not_granted");
                            returnObj.put("action", action);
                            sendJsonData(returnObj);

                        } else {
                            // Permission granted or not required
                            String phonenumber = obj.getString("p");
                            final String number = "tel:" + phonenumber.trim();

                            new Handler(context.getMainLooper()).post(new Runnable() {
                                @Override
                                public void run() {
                                    try {
                                        Intent intent = new Intent(Intent.ACTION_CALL);
                                        intent.setPackage("com.android.phone");
                                        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                        intent.setData(Uri.parse(number));
                                        context.startActivity(intent);

                                    } catch (ActivityNotFoundException e) {

                                        Intent intent = new Intent(Intent.ACTION_CALL);
                                        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                        intent.setData(Uri.parse(number));
                                        context.startActivity(intent);

                                    } catch (Exception e) {
                                        e.printStackTrace();
                                    }
                                }
                            });

                        }
                        break;
                    }

                    // Google won't allow us to update the read status anyway
//                    case "/messages/mark_read": {
//                        String uuid = obj.getString("uid");
//                        if (!util.verifyUUID(context, uuid)) {
//                            return;
//                        }
//
//                        String counterString = obj.getString("c");
//                        String threadId = obj.getString("t");
//                        JSONArray ids = obj.getJSONArray("is");
//                        ArrayList<String> valuesArray = new ArrayList<>();
//                        for (int i = 0; i < ids.length(); ++i) {
//                            String value = ids.getString(i);
//                            valuesArray.add(value);
//                        }
//
//                        smsMmsUriHandler.markSmsMessageAsRead(threadId, valuesArray.toArray(new String[valuesArray.size()]));
//                        JSONArray array = smsMmsUriHandler.getLatestSmsMmsMessagesFromDate(counterString);
//                        JSONObject returnObj = new JSONObject();
//                        returnObj.put("action", action);
//                        returnObj.put("messages", array);
//                        conn.send(returnObj.toString());
//                        break;
//                    }

                    default: {
                        break;
                    }
                }
            } else {
                Log.e(TAG, String.format("Unable to understand the message: %s", message));
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onError(org.java_websocket.WebSocket conn, Exception ex) {
        if (conn != null) {
            Log.i(TAG, conn.toString());
        }
        Log.i(TAG, ex.getMessage());
    }
}
