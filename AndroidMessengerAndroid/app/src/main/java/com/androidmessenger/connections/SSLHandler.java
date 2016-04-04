package com.androidmessenger.connections;

import android.content.Context;

import org.bouncycastle.x509.X509V3CertificateGenerator;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigInteger;
import java.security.InvalidKeyException;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.SignatureException;
import java.security.UnrecoverableKeyException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.Calendar;
import java.util.Date;

import javax.net.ssl.KeyManagerFactory;
import javax.security.auth.x500.X500Principal;

/**
 * Created by Kalyan Vishnubhatla on 4/4/16.
 */
public class SSLHandler {
    private Context context;

    public SSLHandler(Context context) {
        this.context = context;
    }

    public void createSslConfig(String location, String password) throws NoSuchProviderException, NoSuchAlgorithmException, KeyStoreException, IOException, CertificateException, SignatureException, InvalidKeyException, UnrecoverableKeyException {
        String defaultKSType = KeyStore.getDefaultType();
        KeyStore ks = KeyStore.getInstance(defaultKSType);

        File keyStoreFile = new File(context.getExternalCacheDir() + "/" + location);
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());

        // Delete file if exists
        if (keyStoreFile.exists()) {
            keyStoreFile.delete();
        }

        //Initialized it again and insert a cert.
        ks.load(null);
        KeyPair keypair = generateRSAKeyPair(null);
        Certificate c = generateV3Certificate(keypair);
        ks.setKeyEntry("AndroidMessengerKey", keypair.getPrivate(), password.toCharArray(), new Certificate[]{c});
        ks.setCertificateEntry("AndroidMessenger", c);
        ks.store(new FileOutputStream(keyStoreFile), password.toCharArray());
        kmf.init(ks, password.toCharArray());
    }

    public static X509Certificate generateV3Certificate(KeyPair pair) throws InvalidKeyException, NoSuchProviderException, SignatureException {
//        Security.addProvider(new org.bouncycastle.jce.provider.BouncyCastleProvider());
        X509V3CertificateGenerator certGen = new X509V3CertificateGenerator();
        Calendar cal = Calendar.getInstance();
        cal.add(Calendar.YEAR, 1);
        certGen.setSerialNumber(BigInteger.valueOf(System.currentTimeMillis()));
        certGen.setIssuerDN(new X500Principal("CN=AndroidMessenger"));
        certGen.setNotBefore(new Date(System.currentTimeMillis() - 10000));
        certGen.setNotAfter(cal.getTime());
        certGen.setSubjectDN(new X500Principal("CN=AndroidMessenger"));
        certGen.setPublicKey(pair.getPublic());
        certGen.setSignatureAlgorithm("SHA256WithRSAEncryption");
        //certGen.addExtension(X509Extensions.BasicConstraints, true, new BasicConstraints(false));
        //certGen.addExtension(X509Extensions.KeyUsage, true, new KeyUsage(KeyUsage.digitalSignature | KeyUsage.keyEncipherment));
        //certGen.addExtension(X509Extensions.ExtendedKeyUsage, true, new ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth));
        //certGen.addExtension(X509Extensions.SubjectAlternativeName, false, new GeneralNames(new GeneralName(GeneralName.rfc822Name, "test@test.test")));
        return certGen.generateX509Certificate(pair.getPrivate(), "BC");
    }

    public static KeyPair generateRSAKeyPair(String provider) throws NoSuchProviderException, NoSuchAlgorithmException {
        if (provider != null) {
            KeyPairGenerator kpGen = KeyPairGenerator.getInstance("RSA", provider);
            kpGen.initialize(2048);
            return kpGen.generateKeyPair();
        } else {
            KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance("RSA");
            keyPairGenerator.initialize(2048);
            return keyPairGenerator.generateKeyPair();
        }
    }

    public File createFileFromInputStream(InputStream inputStream, File f) {
        try {
            OutputStream outputStream = new FileOutputStream(f);
            byte buffer[] = new byte[1024];
            int length = 0;
            while ((length = inputStream.read(buffer)) > 0) {
                outputStream.write(buffer, 0, length);
            }
            outputStream.close();
            inputStream.close();
            return f;
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }
}
