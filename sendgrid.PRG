* SENDGRID.PRG
* 
* SMALL UTILITY TO SEND EMAILS USING SENDGRID
* WEB PLATFORM.
*
* USAGE:
*
* DO SendGrid
* SG.Initialize(senderEmail, senderName, APIKey)
* 
* LOCAL oMsg
* oMsg = SG.New()
* WITH oMsg
*    .addRecipient("foo1@gmail.com","Foo1")
*    .addRecipient("foo2@gmail.com","Foo2")
*    .addCC("foo3@gmail.com", "Foo3")
*    .Subject = "SendGrid Test"
*    .Body = "This is a test email"
*    .appendBody(" from SendGrid library")
*    .addAttachment("c:\folder\file1.bmp")
*    .addAttachment("c:\folder\file2.bmp","application/octet","logo.bmp")
*    .addInlineAttchment("c:\folder\file3.txt","text/plain")
* ENDWITH
*
* LOCAL lResult
* lResult = SG.Send(oMsg)
* IF lResult
*    ??"SENT!"
* ELSE
*   FOR i = 1 TO SG.Errors.Count
*      ?SG.Errors(i).MEssage, SG.Errors(i).Field, SG.Errors(i).Help
*   ENDFOR
* ENDIF
* 

checkForNQInclude()

IF !FILE("vfplegacy.prg") OR !FILE("vfplegacy.h")
	IF NOT NQInclude("vfplegacy") 
		CANCEL
	ENDIF
	MESSAGEBOX("This library requires VFPLEGACY.PRG library wich has been automatically downloaded. Please, erase SENDGRID.FXP file and try again",48,"SENDGRID.PRG")
	CANCEL
ENDIF

IF NOT NQInclude("json") ;
OR NOT NQInclude("base64Helper") 
	CANCEL
ENDIF

SET PROCEDURE TO vfplegacy ADDITIVE
DO JSON
DO Base64Helper

PUBLIC SG
SG = CREATEOBJECT("SendGridHelper")

RETURN


DEFINE CLASS sendGridHelper AS Custom

	Version = "1.0"
	SenderEmail = ""
	SenderName = ""
	APIKey = ""
	targetUrl = "https://api.sendgrid.com/v3/mail/send"
	Errors = NULL
	lastPayload = ""
	lastResp = NULL
	
	
	* Initialize (method)
	*
	* INITIALIZE HELPER CONFIGURATION VALUES
	*
	PROCEDURE Initialize(pcSenderEmail, pcSenderName, pcAPIKey)
		THIS.senderEmail = pcSenderEmail
		THIS.senderName = pcSenderName
		THIS.APIKey = pcAPIKey
		THIS.Errors = CREATEOBJECT("Collection")
		RETURN
		
	
	
	* New (method)
	*
	* RETURNS A NEW SendGridMessage INSTANCE
	*
	PROCEDURE New
		RETURN CREATEOBJECT("sendGridMsg")
				
				
	* Send (method)
	* 
	* SENDS AN EMAIL USING SENDGRID PLATFORM
	*
	PROCEDURE Send(poMsg)				
		LOCAL cEndPoint,cHeaders,oResp
		cEndpoint = THIS.targetUrl
		cHeaders = "Authorization: Bearer " + THIS.APIKey
		THIS.lastPayload = poMsg.ToJSON()
		THIS.lastResp = JSON.httpPost(cEndpoint, THIS.lastPayload, cHeaders)
		THIS.Errors = CREATEOBJECT("Collection")	
		oResp = THIS.lastResp	
		DO CASE
		   CASE BETWEEN(oResp.statusCode,200,299)
		        lResult = .T.
		        
		   CASE oResp.hasError
		        lResult = .F.
		        THIS.Errors = oResp.lastError
		        
		   CASE oResp.statusCode <> 200
		        lResult = .F.
		        IF ATC("json",oResp.contentType)<>0
		        	THIS.Errors = JSON.Parse(oResp.raw)
		        	IF !JSON.lastError.hasError
		        		THIS.Errors = THIS.Errors.Errors
		        	ELSE
		        		THIS.Errors = JSON.lastError.Message
		        	ENDIF
		        ELSE
		        	THIS.Errors = oResp.raw
		        ENDIF
		       
		ENDCASE
		IF TYPE("THIS.Errors") = "C"
			THIS.Errors = JSON.Parse([{ "message": "] +THIS.Errors + [", "field": null, "help": null }])		
		ENDIF
		RETURN lResult	


ENDDEFINE



DEFINE CLASS sendGridMsg AS Custom
	
	To = NULL
	CC = NULL
	Subject = ""
	Body = ""
	htmlBody = ""
	Attachments = NULL
	lastError = ""
	
	
	* Constructor
	*
	PROCEDURE Init
		THIS.To = CREATEOBJECT("Collection")
		THIS.CC = CREATEOBJECT("Collection")
		THIS.Attachments = CREATEOBJECT("Collection")
		RETURN
		
		
	* addRecipient (method)
	*
	* ADDS A RECIPIENT TO THE "TO" LIST
	*
	PROCEDURE addRecipient(pcEmail, pcName)
	    THIS.TO.Add( CREATEOBJECT("sendGridRecipient", pcEMail, pcName) )
		RETURN
		
		
	* addCC (method)
	*
	* ADDS A RECIPIENT TO THE "CC" LIST
	*
	PROCEDURE addCC(pcEmail, pcName)
	    THIS.CC.Add( CREATEOBJECT("sendGridRecipient", pcEMail, pcName) )
		RETURN
		
		
	* apendBody (method)
	*
	* APPENDS TEXT TO THE BODY STRING
	*
	PROCEDURE appendBody(pcText)
		THIS.body = THIS.body + pcText
		RETURN

	
	* apendHtmlBody (method)
	*
	* APPENDS TEXT TO THE HTML BODY STRING
	*
	PROCEDURE appendHtmlBody(pcText)
		THIS.htmlBody = THIS.htmlBody + pcText
		RETURN
				
				
	* addAttachment (method)
	*
	* ADDS A NEW ITEM TO THE ATTACHMENTS LIST
	*
	PROCEDURE addAttachment(pcFile, pcMIME, pcFullName, pcKind)
	    LOCAL oAttach
	    oAttach = CREATEOBJECT("sendGridAttachment", pcFile)
	    IF NOT oAttach.IsValid
	    	THIS.lastError = oAttach.lastError
	    	RETURN .F.
	    ENDIF
	    IF !EMPTY(pcMIME)
	    	oAttach.MIMEType = pcMIME
	    ENDIF
	    IF !EMPTY(pcFullName)
	    	oAttach.FullName = pcFullName
	    	IF EMPTY(JUSTEXT(oAttach.FullName))
	    		oAttach.fullName = oAttach.FullName + "." + JUSTEXT(pcFile)
	    	ENDIF
	    ENDIF
	    IF !EMPTY(pcKind)
	    	oAttach.Inline = (LOWER(pcKind) == "inline")
	    ENDIF
	    THIS.Attachments.Add(oAttach)
		RETURN
		
		
	* addInlineAttachment (method)
	*
	* ADDS AN INLINE ATTACHMENT
	*
	PROCEDURE addInlineAttachment(pcFile, pcMIME, pcFullName)
		RETURN THIS.addAttachment(pcFile, pcMIME, pcFullName, "inline")
		


	* ToJSON (method)
	*
	* RETURN THE JSON REPRESENTATION OF THE MESSAGE
	* TO BE SENT
	*
	PROCEDURE ToJSON
		LOCAL cTO,cCC,cAttachs,i,oAttach,oRecipient,cContentType,cContent,cJSON
		STORE "" TO cTO,cCC,cAttachs
		FOR i = 1 TO THIS.TO.Count
		    oRecipient = THIS.TO.Item(i)
			cTO = cTO + IIF(i=1,"",",") + oRecipient.ToJSON()
		ENDFOR
		FOR i = 1 TO THIS.CC.Count
		    oRecipient = THIS.CC.Item(i)
			cCC = cCC + IIF(i=1,"",",") + oRecipient.ToJSON()
		ENDFOR
		FOR i = 1 TO THIS.Attachments.Count
		    oAttach = THIS.Attachments.Item(i)
			cAttachs = cAttachs + IIF(i=1,"",",") + oAttach.ToJSON()
		ENDFOR	
		IF EMPTY(THIS.htmlBody)
			cContentType = "text/plain"
			cContent = THIS.Body
		ELSE
			cContentType = "text/html"
			cContent = THIS.htmlBody
		ENDIF		
		cJSON = ""
		TEXT TO cJSON TEXTMERGE NOSHOW
		{
			"from": { "email":"<<SG.senderEmail>>","name":"<<SG.senderName>>" },
			"personalizations":[
				{
					"to": [<<cTO>>]
					,"cc": [<<cCC>>]
					,"subject": "<<THIS.subject>>"
				}
			],
			"content": [
				{"type": "<<cContentType>>", "value": "<<cContent>>"}
			]
			,"Attachments": [<<cAttachs>>]
		}
		ENDTEXT
		IF EMPTY(cCC)
			cJSON = STRT(cJSON,',"cc": []', "")
		ENDIF
		IF EMPTY(cAttachs)
			cJSON = STRT(cJSON,',"Attachments": []', "")
		ENDIF
		RETURN cJSON

ENDDEFINE


DEFINE CLASS sendGridRecipient AS Custom
	Email = ""
	fullName = ""
	
	PROCEDURE Init(pcEmail, pcName)
		THIS.Email = pcEmail
		THIS.fullName = EVL(pcName,"")
		RETURN
		
	PROCEDURE ToJSON
		RETURN [{"email":"] + THIS.email + [","name":"] + THIS.fullName + ["}]
ENDDEFINE



DEFINE CLASS sendGridAttachment AS Custom
	fileName = ""
	fullName = ""
	MIMEType = ""
	Inline = .F.
	Content = ""
	IsValid = .F.
	lastError = ""
	
	PROCEDURE Init(pcFile)
	    IF NOT FILE(pcFile)
	        THIS.lastError = "File '" + pcFile + "' not found"
	    	RETURN 
	    ENDIF
	    THIS.fileName = FULLPATH(pcFile)
	    THIS.fullName = JUSTFNAME(pcFile)
	    THIS.Content = B64.encodeFile(THIS.fileName, .T.)
	    THIS.Inline = .F.
	    THIS.IsValid = .T.
	    LOCAL cExt
	    cExt = UPPER(JUSTEXT(pcFile))
	    DO CASE
	       CASE INLIST(cExt,"TXT","CSV")
	            THIS.MIMEType = "text/plain"

	       CASE INLIST(cExt,"HTM","HTML")
	            THIS.MIMEType = "text/html"
	            
	       CASE cExt = "PDF"
	            THIS.MIMEType = "application/pdf"
	            
	       CASE cExt = "JSON"
	            THIS.MIMEType = "application/json"
	            
	       CASE cExt = "XML"
	            THIS.MIMEType = "application/xml"

	       CASE INLIST(cExt,"MP4","F4A","F4B","M4V","F4P","F4V")
	            THIS.MIMEType = "audio/mp4"
	            	            	                   
		   OTHERWISE
		        THIS.MIMEType = "application/octet-stream"	       
	    ENDCASE
		RETURN

	PROCEDURE ToJSON
		RETURN [{] +;
		       [  "content": "] + THIS.content + [",] + ;
		       [  "type": "] + THIS.MIMEType + [",] + ;
		       [  "filename": "] + THIS.fullName + [",] + ;
		       [  "disposition": "] + IIF(THIS.inline,"inline","attachment") + ["] + ;
		       [ }]
	
ENDDEFINE


	
	
PROCEDURE checkForNQInclude
   IF NOT FILE("nqinclude.prg")
      STRTOFILE(httpGetFile("https://raw.githubusercontent.com/vespina/nqinclude/main/nqinclude.prg"),"nqinclude.prg")
      IF NOT FILE("nqinclude.prg")
         MESSAGEBOX("This library requires NQINCLUDE.PRG wich could not be downloaded at this time",48,"JSON.PRG")
         CANCEL
      ENDIF
   ENDIF
   RETURN

PROCEDURE httpGetFile(pcUrl)
   pnTimeout = IIF(VARTYPE(pnTimeOut)<>"N",15,pnTimeout) 	
   LOCAL oHTTP
   oHTTP = CREATEOBJECT("MSXML2.XMLHTTP")
   oHTTP.open("GET", pcUrl, .F.)
   oHTTP.Send()
   LOCAL nTimeOut
   nTimeout = SECONDS()
   DO WHILE oHTTP.readyState<>4 OR (SECONDS() - nTimeout) > 15
      DOEVENTS
   ENDDO
   IF oHTTP.readyState <> 4 OR !BETWEEN(oHTTP.status,200,299)
      RETURN ""
   ENDIF 
   RETURN oHTTP.responseText()