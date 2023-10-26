
/*------------------------------------------------------------------------
   File        : PugWebHandler
   Purpose     :
   Syntax      :
   Description :
   Author(s)   : bronco
   Created     : Wed May 17 15:32:46 CEST 2017
   Notes       :
 ----------------------------------------------------------------------*/


block-level on error undo, throw.

using OpenEdge.Core.Collections.StringStringMap.
using OpenEdge.Core.String.
using OpenEdge.Net.HTTP.Cookie.
using OpenEdge.Net.HTTP.HttpHeader.
using OpenEdge.Net.HTTP.IHttpResponse.
using OpenEdge.Web.IWebRequest.
using OpenEdge.Web.WebHandler.
using OpenEdge.Web.WebResponse.
using OpenEdge.Web.WebResponseWriter.
using Progress.Json.ObjectModel.JsonArray.
using Progress.Json.ObjectModel.JsonObject.
using Progress.Lang.OERequestInfo.

class PugWebHandler inherits WebHandler:

  define private property queryParameters as StringStringMap no-undo get. set.
  define private static property callCount as integer no-undo get. set.

  constructor public PugWebHandler():
    // empty
  end.

  method override protected integer HandleGet(request as IWebRequest):

    var IHttpResponse response.
    var WebResponseWriter writer.
    var char endpoint.
    var logical errorFound.

    extractHttpInfo(request).

    endpoint = request:GetContextValue('URI_FINAL_MATCH_GROUP').
    message substitute('GET: &1', endpoint).

    callCount += 1.

    errorFound = false.
    case endpoint:

      when '/' then
        response = processHome(request).

      when '/get' then
        response = processGet(request).
        
      when '/protected/get' then
        response = processGet(request).
        
      when '/unprotected/get' then
        response = processGet(request).        

      when '/cookie' then
        response = processCookie(request, false).

      when '/persistentcookie' then
        response = processCookie(request, true).

      when '/customer' then
        response = processCustomer(request, false).

      when '/customercache' then
        response = processCustomer(request, true).

      when '/propath' then
        response = processPropath(request).

      // entries to fiddle with auth
      when '/admin' or when '/system' or when '/info' then
        response = processSandboxCalls(request).

      when '' then
        response = processHealth(request).

      otherwise do:
        response = processNotAllowed(request).
        errorFound = true.
      end.

    end case.

    writer = new WebResponseWriter(response).
    writer:Open().
    writer:Close().

    return 0.

  end method.  // HandleGet


  method override protected integer HandlePost(request as IWebRequest):

    var IHttpResponse response.
    var WebResponseWriter writer.
    var char endpoint.

    endpoint = request:GetContextValue('URI_FINAL_MATCH_GROUP').

    case endpoint:

      when '/' then
        response = processHome(request).

      when '/post' then
        response = processGet(request).  // W.I.P.

      otherwise do:
        response = processNotAllowed(request).
      end.

    end case.

    writer = new WebResponseWriter(response).
    writer:Open().
    writer:Close().

    return 0.

  end method.  // HandlePost


  method override protected integer HandleNotAllowedMethod( webRequest as OpenEdge.Web.IWebRequest ):
    undo, throw new Progress.Lang.AppError('METHOD NOT IMPLEMENTED').
  end method.


  method override protected integer HandleNotImplemented(webRequest as OpenEdge.Web.IWebRequest ):
    undo, throw new Progress.Lang.AppError('METHOD NOT IMPLEMENTED').
  end method.


  method private PugWebHandler addHeaders(request as IWebRequest, json as JsonObject):

    var JsonObject headerJson.
    var HttpHeader[] headers.
    var HttpHeader currentHeader.
    var int headerCount.
    var int i.

    headerJson = new JsonObject().

    headerCount = request:GetHeaders(headers).
    do i = 1 to headerCount:
      currentHeader = headers[i].
      headerJson:Add(normalizeHeaderName(currentHeader:Name), currentHeader:Value).
    end.

    json:Add('headers', headerJson).

    return this-object.

  end method.  // addHeaders


  method private PugWebHandler addQueryParameters(request as IWebRequest, json as JsonObject):

    var JsonObject parameterJson.
    var int parameterCount.
    var int i.
    var char parameters.
    var char currentEntry.
    var char parameterName.
    var char parameterValue.

    parameterJson = new JsonObject().
    parameters = request:GetContextValue('QUERY_STRING').

    parameterCount = num-entries(parameters, '&').
    do i = 1 to parameterCount:
      currentEntry = entry(i, parameters, '&').
      parameterName = entry(1, currentEntry, '=').
      parameterValue = urlDecode(entry(2, currentEntry, '=')).
      parameterJson:Add(parameterName, parameterValue).
    end.

    json:Add('args', parameterJson).

    return this-object.

  end method.  // addQueryParameters


  method private PugWebHandler addInstanceInfo(request as IWebRequest, json as JsonObject):

    var JsonObject instanceJson.
    var char environment.
    var char instanceId.

    environment = os-getenv('OE_ENVIRONMENT').
    if (environment = ?) then
        environment = '<unknown>'.

    instanceId = os-getenv('INSTANCE_ID').
    if (instanceId = ?) then
      instanceId = 'default'.

    instanceJson = new JsonObject().
    instanceJson:Add('environment', environment).
    instanceJson:Add('id', instanceId).
    instanceJson:Add('calls', callCount).

    json:Add('instance', instanceJson).

    return this-object.

  end method.  // addInstanceInfo


  method private PugWebHandler addPathParameters(request as IWebRequest, json as JsonObject):

    var JsonObject parameterJson.
    var int parameterCount.
    var int i.
    var char parameters.
    var char parameterName.
    var char parameterValue.

    parameterJson = new JsonObject().
    parameters = request:PathParameterNames.

    parameterCount = num-entries(parameters).
    do i = 1 to parameterCount:
      parameterName = entry(i, parameters).
      parameterValue = request:GetPathParameter(parameterName).
      parameterJson:Add(parameterName, parameterValue).
    end.

    json:Add('pathparameters', parameterJson).

    return this-object.

  end method.  // addPathParameters


  method private PugWebHandler addContext(request as IWebRequest, json as JsonObject):

    var JsonObject parameterJson.
    var int parameterCount.
    var int i.
    var char parameters.
    var char parameterName.
    var char parameterValue.

    parameterJson = new JsonObject().
    parameters = request:ContextNames.

    parameterCount = num-entries(parameters).
    do i = 1 to parameterCount:
      parameterName = entry(i, parameters).
      parameterValue = request:GetContextValue(parameterName).
      parameterJson:Add(parameterName, parameterValue).
    end.

    json:Add('context', parameterJson).

    return this-object.

  end method.  // addContext


  method private PugWebHandler addOpenEdgeInformation(request as IWebRequest, json as JsonObject):

    this-object
      :addContext(request, json)
      :addPathParameters(request, json)
      :addPropath(request, json)
      :addVersion(request, json)
      :addCurrentRequestInfo(request, json)
      .

    return this-object.

  end method.  // addOpenEdgeInformation


  method private PugWebHandler addStandardHttp(request as IWebRequest, json as JsonObject):

    var JsonObject local.

    json:Add('origin', request:RemoteHost).
    json:Add('url', request:URI:BaseURI + request:URI:Path).

    local = new JsonObject().
    local:Add('ip', request:GetContextValue('LOCAL_ADDR')).

    json:Add('local', local).

    return this-object.

  end method.  // addStandardHttp


  method private IHttpResponse processCookie(request as IWebRequest, persistentCookie as logical):

    var IHttpResponse response.
    var Cookie cookie.
    var char path.
    var int maxAge.
    var char urlMaxage.

    response = new WebResponse().
    response:ContentType = 'text/plain'.
    response:Entity = new String('you got a cookie').

    path = request:GetContextValue('SERVLET_APPLICATION_URL') + request:GetContextValue('URI_FINAL_MATCH_GROUP').

    if (persistentCookie) then do:
      maxAge = 600.
      urlMaxage = queryParameters:Get('maxage').
      if (urlMaxage > '') then
        maxAge = integer(urlMaxage) no-error.

      cookie = new Cookie('test', 'localhost', path, 'succeeded', maxAge, ?, false, true, ?).

    end.
    else
      cookie = new Cookie('test', 'localhost', path, 'succeeded').

    response:SetCookie(cookie).

    return response.

  end method.  // processCookie


  method private IHttpResponse processCustomer(request as IWebRequest, cached as logical):

    var IHttpResponse response.
    var JsonArray json.
    var HttpHeader cacheHeader.

    response = new WebResponse().

    if (not connected('sports2000') and not connected('sports2020')) then do:
      response:ContentType = 'text/plain'.
      response:Entity = new String('sports2000/2020 not connected').
    end.
    else do:
      json = customersToJson(request).
      response:ContentType = 'application/json'.
      response:Entity = json.
      if (cached) then do:
        cacheHeader = new HttpHeader('Cache-Control', 'max-age=60').
        response:SetHeader(cacheHeader).
      end.
    end.

    return response.

  end method.  // processCustomer


  method private IHttpResponse processGet(request as IWebRequest):

    var IHttpResponse response.
    var JsonObject json.
    var JsonObject oeJson.

    response = new WebResponse().
    response:ContentType = 'application/json'.

    json = new JsonObject().
    this-object
        :addQueryParameters(request, json)
        :addInstanceInfo(request, json)
        :addStandardHttp(request, json)
        :addHeaders(request, json)
        .

    oeJson = new JsonObject().

    if (queryParameters:Get('openedge') = 'true') then do:
      addOpenEdgeInformation(request, oeJson).
      json:Add('openedge', oeJson).
    end.

    response:Entity = json.

    return response.

  end method.  // processGet


  method private IHttpResponse processPropath(request as IWebRequest):

    var IHttpResponse response.
    var JsonObject json.

    response = new WebResponse().
    response:ContentType = 'application/json'.

    json = new JsonObject().
    json:Add('propath', getPropathJson()).

    response:Entity = json.

    return response.

  end method.  // processPropath


  method private JsonArray getPropathJson():

    var JsonArray jsonArray.
    var int i.
    var int numEntries.

    jsonArray = new JsonArray().

    numEntries = num-entries(propath).
    do i = 1 to numEntries:
      jsonArray:Add(entry(i, propath)).
    end.

    return jsonArray.

  end method.  // getPropathJson


  method private PugWebHandler addPropath(request as IWebRequest, json as JsonObject):

    json:Add('propath', getPropathJson()).

    return this-object.

  end method.  // addPropath


  method private PugWebHandler addVersion(request as IWebRequest, json as JsonObject):

    json:Add('version', proversion()).

    return this-object.

  end method.  // addVersion


  method private PugWebHandler addCurrentRequestInfo(request as IWebRequest, json as JsonObject):

    var OERequestInfo currentRequestInfo.
    var JsonObject jsonRequestInfo.
    var JsonObject jsonCP.


    currentRequestInfo = session:current-request-info.

    jsonRequestInfo = new JsonObject().
    jsonRequestInfo:Add('agentId', currentRequestInfo:AgentId).
    jsonRequestInfo:Add('clientContextId', currentRequestInfo:ClientContextId).
    jsonRequestInfo:Add('procedureName', currentRequestInfo:ProcedureName).
    jsonRequestInfo:Add('requestId', currentRequestInfo:RequestId).
    jsonRequestInfo:Add('sessionId', currentRequestInfo:SessionId).
    jsonRequestInfo:Add('threadId', currentRequestInfo:ThreadId).

    jsonCP = getCPInfo(currentRequestInfo).
    jsonRequestInfo:Add("clientPrincipal", jsonCP).

    json:Add('currentRequestInfo', jsonRequestInfo).

    return this-object.

  end method.  // addCurrentRequestInfo


  method private JsonObject getCPInfo(currentRequestInfo as OERequestInfo):

    var JsonObject jsonCP.
    var handle hCP.
    var char propList.
    var int propCount.
    var char propName.
    var char propValue.
    var int i.

    jsonCP = new JsonObject().

    hCP = currentRequestInfo:GetClientPrincipal().
    if (valid-handle(hCP)) then do:

      jsonCP:Add('userid', hCP:user-id).

      propList = hCP:list-property-names().
      propCount = num-entries(propList).

      do i = 1 to propCount:
        propName = entry(i, propList).
        propValue = hCP:get-property(propName).
        jsonCP:Add(propName, propValue).
      end.

    end.  // if (valid-handle(hCP))...

    return jsonCP.

  end method.  // getCPInfo


  method private IHttpResponse processHealth(request as IWebRequest):

    var IHttpResponse response.

    // for demo purposes we return 'unhealthy' after 10 calls
    response = new WebResponse().
    response:StatusCode = (if (callCount <= 10) then 200 else 500).
    response:Entity = new String('').
    response:ContentType = 'text/plain'.

    return response.

  end method.  // processHealth


  method private IHttpResponse processHome(request as IWebRequest):

    var IHttpResponse response.
    var longchar htmlContent.
    var char htmlFile.

    htmlFile = search('home.html').
    copy-lob file htmlFile to htmlContent.

    response = new WebResponse().
    response:Entity = new String(htmlContent).
    response:ContentType = 'text/html'.

    return response.

  end method.  // processHome


  method private IHttpResponse processSandboxCalls(request as IWebRequest):

    var IHttpResponse response.
    var JsonObject json.

    json = new JsonObject().
    json:Add('get', string(request:GetContextValue('PATH_INFO'))).

    response = new WebResponse().
    response:Entity = json.
    response:ContentType = 'application/json'.

    return response.

  end method.  // processSandboxCalls


  method private IHttpResponse processNotAllowed(request as IWebRequest):

    var IHttpResponse response.

    response = new WebResponse().

    response:StatusCode = 405.
    response:StatusReason = 'Method Not Allowed'.
    response:ContentType = 'text/html'.
    response:Entity = new String(
      '405: ' + request:Method + ' of ' + quoter(request:GetContextValue('URI_FINAL_MATCH_GROUP')) + ' not allowed'
    ).

    return response.

  end method.  // processNotAllowed


  method private character urlDecode(urlEntry as character):

    // for now just the spaces
    urlEntry = replace(urlEntry, '%20', ' ').

    return urlEntry.

  end method.  // urlDecode


  method private void reset():
    delete object queryParameters no-error.
  end method.  // reset


  method private void extractHttpInfo(request as IWebRequest):

    var char parameters.
    var int parameterCount.
    var int i.
    var char currentEntry.
    var char parameterName.
    var char parameterValue.

    queryParameters = new StringStringMap().

    parameters = request:GetContextValue('QUERY_STRING').

    parameterCount = num-entries(parameters, '&').
    do i = 1 to parameterCount:
      currentEntry = entry(i, parameters, '&').
      parameterName = entry(1, currentEntry, '=').
      parameterValue = urlDecode(entry(2, currentEntry, '=')).
      queryParameters:Put(parameterName, parameterValue).
    end.

  end method.  // extractHttpInfo


  method private JsonArray customersToJson(request as IWebRequest):

    var JsonArray json.
    var JsonObject recordJson.

    var handle queryHandle.
    var handle bufferHandle.
    var int i.
    var char id.

    json = new JsonArray().

    id = queryParameters:Get('id').

    create query queryHandle.
    create buffer bufferHandle for table 'customer'.
    queryHandle:set-buffers(bufferHandle).
    queryHandle:query-prepare('for each customer' + if (id > '') then ' where custnum = ' + quoter(id) else '').
    queryHandle:query-open().

    queryHandle:get-first().
    do while (not queryHandle:query-off-end):
      recordJson = new JsonObject().
      do i = 1 to bufferHandle:num-fields:
        recordJson:Add(bufferHandle:buffer-field(i):name, bufferHandle:buffer-field(i):buffer-value).
      end.
      json:Add(recordJson).
      queryHandle:get-next().
    end.

    return json.

    finally:
       delete object queryHandle no-error.
       delete object bufferHandle no-error.
    end finally.

  end method.  // customersToJson


  /* this method is a copy of the one in HttpHelper. The copy here is to make
   * this handler dependy free, other than OpenEdge.* and Progress.*
   */
  method private character normalizeHeaderName(headerName as character):

    var logical nextCharUpper.
    var char resultString.
    var int headerNameLength.
    var int i.
    var char currentChar.

    headerNameLength = length(headerName).
    nextCharUpper = true.
    do i = 1 to headerNameLength:

      currentChar = substring(headerName, i, 1).

      if (nextCharUpper) then do:
        resultString += caps(currentChar).
        nextCharUpper = false.
        next.
      end.

      if (currentChar = '_') then
        currentChar = '-'.

      if (currentChar = '-') then
        nextCharUpper = true.

      resultString += lc(currentChar).

    end.

    return resultString.

  end method.  // normalizeHeaderName

end class.

