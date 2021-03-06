package com.androidmessenger.connections;

import android.Manifest;
import android.content.ActivityNotFoundException;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.widget.Toast;

import com.androidmessenger.R;
import com.androidmessenger.service.AndroidAppService;
import com.androidmessenger.urihandler.ContactsUriHandler;
import com.androidmessenger.urihandler.SmsMmsUriHandler;
import com.androidmessenger.util.Uris;
import com.androidmessenger.util.UserPreferencesManager;
import com.androidmessenger.util.Util;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.InvalidKeyException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.SignatureException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLServerSocketFactory;

import fi.iki.elonen.NanoHTTPD;

/**
 * Created by Kalyan Vishnubhatla on 3/21/16.
 */
public class WebServer extends NanoHTTPD {
    private static final String TAG = WebServer.class.getSimpleName();
    public static final int PORT_NUMBER = 5000;
    private Context context;
    private Util util;
    private SmsMmsUriHandler smsMmsUriHandler;

    // SSL keystore created in SSLHandler.createSslConfig
    private final String DEFAULT_PASSWORD = "passwordWillChangeForReleases";
    private final String KEY_STORE_NAME = "androidmessenger.keystore";

    public WebServer(AndroidAppService service) throws IOException {
        super(PORT_NUMBER);
        this.context = service.getBaseContext();
        this.util = new Util();
        this.smsMmsUriHandler = new SmsMmsUriHandler(service);

        try {
            initiateSslConfiguration();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void initiateSslConfiguration() throws NoSuchProviderException, NoSuchAlgorithmException, KeyStoreException, IOException, CertificateException, SignatureException, InvalidKeyException, UnrecoverableKeyException {
        String defaultKSType = KeyStore.getDefaultType();
        KeyStore ks = KeyStore.getInstance(defaultKSType);
        File keyStoreFile = new File(context.getExternalFilesDir(null) + "/" + KEY_STORE_NAME);
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());

        // Copy keystore file from our assets to the external files directory if needed.
        if (!keyStoreFile.exists()) {
            InputStream inputStream = context.getAssets().open(KEY_STORE_NAME);
            SSLHandler handler = new SSLHandler(context);
            handler.createFileFromInputStream(inputStream, keyStoreFile);
        }

        // Double check that it exists
        if (keyStoreFile.exists()) {
            ks.load(new FileInputStream(keyStoreFile), DEFAULT_PASSWORD.toCharArray());
            kmf.init(ks, DEFAULT_PASSWORD.toCharArray());
            SSLServerSocketFactory sslsf = makeSSLSocketFactory(ks, kmf.getKeyManagers());
            makeSecure(sslsf, null);
        }
    }

    public Response serve(IHTTPSession session) {
        String urlString = session.getUri();
        Log.i(TAG, urlString);
        switch (urlString) {
            case "/messages/fromcounter": {
                Response r = verifyUuid(session.getParms().get("uid"));
                if (r != null) {
                    return r;
                }

                String counterString = session.getParms().get("c");
                JSONArray array = smsMmsUriHandler.getLatestSmsMmsMessagesFromDate(counterString);
                return newFixedLengthResponse(array.toString());
            }

            case "/messages/all": {
                Response r = verifyUuid(session.getParms().get("uid"));
                if (r != null) {
                    return r;
                }

                JSONArray array = smsMmsUriHandler.getLatestSmsMmsMessagesFromDate(null);
                return newFixedLengthResponse(array.toString());
            }

            case "/message/send": {
                // POST method
                Integer contentLength = Integer.parseInt(session.getHeaders().get("content-length"));
                byte[] buf = new byte[contentLength];
                try {
                    session.getInputStream().read(buf, 0, contentLength);
                    String data = new String(buf);
                    JSONObject json = new JSONObject(data);

                    Response r = verifyUuid(json.getString("uid"));
                    if (r != null) {
                        return r;
                    }

                    String number = json.getString("n");
                    String text = json.getString("t");
                    String counterString = json.getString("c");
                    String uuid = json.getString("id");
                    smsMmsUriHandler.sendSms(number, text, uuid);

                    JSONArray array = smsMmsUriHandler.getLatestSmsMmsMessagesFromDate(counterString);
                    Log.i(TAG, "SENDING MESSAGE: " + Integer.toString(array.length()));
                    Log.i(TAG, array.toString());
                    return newFixedLengthResponse(array.toString());

                } catch (IOException e) {
                    e.printStackTrace();
                } catch (JSONException e) {
                    e.printStackTrace();
                }

                return newFixedLengthResponse("");
            }

            case "/message/mms/file": {
                // URL to download media from MMS part (audio, video, photo files)
                Response r = verifyUuid(session.getParms().get("uid"));
                if (r != null) {
                    return r;
                }

                InputStream fis = null;
                String part_id = session.getParms().get("part_id");
                String mimetype = "";
                Uri partURI = Uri.parse(Uris.MmsPart + "/" + part_id);
                ContentResolver contentResolver = context.getContentResolver();

                try {
                    mimetype = contentResolver.getType(partURI);
                    fis = contentResolver.openInputStream(partURI);
                } catch (Exception e) {
                    e.printStackTrace();
                }

                return newChunkedResponse(Response.Status.OK, mimetype, fis);
            }

            case "/new_device": {
                try {
                    JSONObject jobj = new JSONObject();

                    String uuid = session.getParms().get("uid");
                    String deviceName = session.getParms().get("dn");
                    String currentUUID = UserPreferencesManager.getInstance().getValueFromPreferences(context, context.getString(R.string.preferences_device_uuid));
                    if (currentUUID != null && !util.verifyUUID(context, uuid)) {
                        new Handler(context.getMainLooper()).post(new Runnable() {
                            public void run() {
                                Toast.makeText(context, "New device tried to connect! Device ID does not match.", Toast.LENGTH_SHORT).show();
                            }
                        });
                        return verifyUuid(null);

                    } else {
                        UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_device_uuid), uuid);
                        UserPreferencesManager.getInstance().setStringInPreferences(context, context.getString(R.string.preferences_device_name), deviceName);
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                        jobj.put("permission", "denied");
                    } else {
                        ContactsUriHandler contactsUriHandler = new ContactsUriHandler(context);
                        jobj.put("contacts", contactsUriHandler.getAllContacts());
                    }
                    return newFixedLengthResponse(jobj.toString());
                } catch (JSONException e) {
                    e.printStackTrace();
                }

                return newFixedLengthResponse("");
            }

            case "/phone_call": {
                Integer contentLength = Integer.parseInt(session.getHeaders().get("content-length"));
                byte[] buf = new byte[contentLength];
                try {
                    session.getInputStream().read(buf, 0, contentLength);
                    String data = new String(buf);
                    JSONObject json = new JSONObject(data);

                    Response r = verifyUuid(json.getString("uid"));
                    if (r != null) {
                        return r;
                    }

                    JSONObject jobj = new JSONObject();
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                        // Permission not granted
                        jobj.put("permission", "not_granted");

                    } else {
                        // Permission granted or not required
                        String phonenumber = json.getString("p");
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

                        jobj.put("permission", "granted");
                    }

                    return newFixedLengthResponse(jobj.toString());
                } catch (JSONException e) {
                    e.printStackTrace();
                } catch (IOException e) {
                    e.printStackTrace();
                }

                return newFixedLengthResponse("");
            }

            // This API is just for testing. Will be removed in future
//            case "/unreadmessages": {
//
//                ContentResolver cr = context.getContentResolver();
//                android.database.Cursor cursor = cr.query(Uris.Sms, null, "read=0", null, null);
//                if (cursor == null) {
//                    return null;
//                }
//                String response = null;
//                StringBuffer responseBuffer = new StringBuffer();
//                if (cursor.moveToFirst()) {
//                    for (int i = 0; i < cursor.getColumnCount(); i++) {
//                        responseBuffer.append(cursor.getColumnName(i) + "=" + cursor.getString(cursor.getColumnIndexOrThrow(cursor.getColumnName(i))) + "<br>");
//                    }
//                }
//                responseBuffer.append(Integer.toString(cursor.getCount()));
//                if (cursor != null && !cursor.isClosed()) {
//                    cursor.close();
//                }
//                response = responseBuffer.toString();
//
//                return newFixedLengthResponse(response);
//
//            }

            // This API is just for testing. Will be removed in future
            case "/message": {
                Response r = verifyUuid(session.getParms().get("uid"));
                if (r != null) {
                    return r;
                }

                String response = "";
                String msgId = session.getParms().get("id");

                android.database.Cursor c = context.getContentResolver().query(Uris.Mms, null, "_id=" + msgId, null, null);

                if (c.moveToFirst()) {
                    StringBuffer responseBuffer = new StringBuffer();
                    for (int i = 0; i < c.getColumnCount(); i++) {
                        responseBuffer.append(c.getColumnName(i) + "=" + c.getString(c.getColumnIndexOrThrow(c.getColumnName(i))) + "<br>");
                    }
                    response = responseBuffer.toString();
                }
                c.close();

                return newFixedLengthResponse(response);
            }

            // This API is just for testing. Will be removed in future
//            case "/messages/mms": {
//                Response r = verifyUuid(session.getParms().get("uid"));
//                if (r != null) {
//                    return r;
//                }
//
//                String response = "";
//                String msgId = session.getParms().get("id");
//                String filter = null;
//                if (msgId != null) {
//                    filter = "_id=" + msgId;
//                }
//
//                android.database.Cursor c = context.getContentResolver().query(Uris.Mms, null, filter, null, null);
//
//                if (c.moveToFirst()) {
//                    do {
//                        try {
//                            String id = c.getString(c.getColumnIndexOrThrow("_id"));
//                            JSONObject msg = new JSONObject();
//
//                            response = "";
//                            String[] cols = c.getColumnNames();
//                            for (String col : cols) {
//                                msg.put(col, c.getString(c.getColumnIndexOrThrow(col)));
//                            }
//                            msg.put("address", smsMmsUriHandler.getAddressesForMmsMessages(id));
//                            msg.put("parts", smsMmsUriHandler.getMmsPartsInJsonArray(id));
//
//                            response = msg.toString();
//
//                        } catch (JSONException j) {
//                            j.printStackTrace();
//                        }
//                    } while (c.moveToNext());
//                }
//
//                c.close();
//
//                return newFixedLengthResponse(response);
//            }

            default: {
                return newFixedLengthResponse("");
            }
        }
    }

    private Response verifyUuid(String uuid) {
        if (uuid == null || !util.verifyUUID(context, uuid)) {
            try {
                JSONObject obj = new JSONObject();
                obj.put("UUID", "MISMATCH");
                return newFixedLengthResponse(obj.toString());
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
        return null;
    }
}
