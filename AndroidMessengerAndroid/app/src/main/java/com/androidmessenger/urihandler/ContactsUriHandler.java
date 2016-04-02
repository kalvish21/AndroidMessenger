package com.androidmessenger.urihandler;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.provider.ContactsContract;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.Serializable;

/**
 * Created by Kalyan Vishnubhatla on 4/2/16.
 */
public class ContactsUriHandler implements Serializable {
    private static final long serialVersionUID = 2318107894216408372L;
    private final String TAG = ContactsUriHandler.class.getSimpleName();
    private Context context;

    public ContactsUriHandler(Context context) {
        this.context = context;
    }

    public JSONArray getAllContacts() {
        ContentResolver cr = context.getContentResolver();
        Cursor cur = cr.query(ContactsContract.Contacts.CONTENT_URI, null, null, null, null);
        JSONArray contactsarray = new JSONArray();

        try {
            while (cur.moveToNext()) {
                if (Integer.parseInt(cur.getString(cur.getColumnIndex(ContactsContract.Contacts.HAS_PHONE_NUMBER))) > 0) {
                    String id = cur.getString(cur.getColumnIndex(ContactsContract.Contacts._ID));
                    String name = cur.getString(cur.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME));

                    Cursor phones = cr.query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, null, ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = " + id, null, null);
                    if (phones.getColumnCount() > 0) {
                        JSONObject obj = new JSONObject();
                        obj.put("id", id);
                        obj.put("name", name);
                        JSONArray phoneArray = new JSONArray();
                        while (phones.moveToNext()) {
                            try {
                                String cNumber = phones.getString(phones.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER));
                                if (cNumber != null) {
                                    phoneArray.put(cNumber);
                                }

                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        }
                        phones.close();
                        if (phoneArray.length() > 0) {
                            obj.put("phones", phoneArray);
                            contactsarray.put(obj);
                        }
                    }
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            cur.close();
        }
        return contactsarray;
    }
}
