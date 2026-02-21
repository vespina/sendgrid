# sendgrid.prg
**Version 1.0**

Small utility to send custom emails using [SendGrid](https://sendgrid.com/) platform.  The SendGrid platform free plan allows you to send up to 100 emails every day, so its really helpfull for simple applications.  To use the platform:

1. Create a new account with free plan
2. Creates a sender
3. Creates an API key


### USAGE

    DO SendGrid
    SG.Initialize(senderEmail, senderName, APIKey)

    LOCAL oMsg
    oMsg = SG.New()
    WITH oMsg
      .addRecipient("foo1@gmail.com","Foo1")
      .addRecipient("foo2@gmail.com","Foo2")
      .addCC("foo3@gmail.com", "Foo3")
      .Subject = "SendGrid Test"
      .Body = "This is a test email"
      .appendBody(" from SendGrid library")
      .addAttachment("c:\folder\file1.bmp")
      .addAttachment("c:\folder\file2.bmp","application/octet","logo.bmp")
      .addInlineAttachment("c:\folder\file3.txt","text/plain")
    ENDWITH
    
    LOCAL lResult
    lResult = SG.Send(oMsg)
    
    IF lResult
       ??"SENT!"
    ELSE
       FOR i = 1 TO SG.Errors.Count
          ?SG.Errors(i).MEssage, SG.Errors(i).Field, SG.Errors(i).Help
       ENDFOR
    ENDIF

### SENDING HTML EMAILS
Just use *htmlBody* property and *appendHtmlBody()* methods, instead of *Body* and *appendBody()*.

### CHANGE HISTORY
|DATE         |USER|COMMENTS           |
|-------------|----|------------------ |
|FEB 24, 2024 |VES |Some outdated documentation fixed |
|APR 16, 2022 |VES |Initial version    |

