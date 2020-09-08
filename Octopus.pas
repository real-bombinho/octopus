unit Octopus;

interface

uses System.SysUtils, System.DateUtils;

const
  OctopusURL = 'https://api.octopus.energy/';
  OctopusUserAgent = 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:12.0) '+
    'Gecko/20100101 Firefox/12.0';

type

  TOctopus = class
  private
    FLastResponse: AnsiString;
    FLastFetched: TDateTime;
    FAPIKey: AnsiString;
    function fetch(const url: string): boolean;
    function getLastResponse: AnsiString;
  public
    property LastResponse: AnsiString read getLastResponse;
    property APIKey: AnsiString write FAPIKey;
    constructor Create; overload;
    constructor Create(const Key: String); overload;
  end;

implementation

uses IdHTTP, IdSSLOpenSSL,IdCompressorZLib;

{ TOctopus }

constructor TOctopus.Create;
begin
  Create('');
end;

constructor TOctopus.Create(const key: String);
begin
  FAPIKey := key;
  FLastResponse := '';
  FLastFetched := 0;
end;

function TOctopus.fetch(const url: string): boolean;
var Id_HandlerSocket : TIdSSLIOHandlerSocketOpenSSL;
    IdHTTP1: TIdHTTP;
    s: string;
begin
  result := false;
  IdHTTP1 := TIdHTTP.Create(nil);
  IdHTTP1.Compressor := TIdCompressorZLib.Create(nil);
  Id_HandlerSocket := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  try
    Id_HandlerSocket.DefaultPort := 443;
    Id_HandlerSocket.SSLOptions.Mode := sslmClient;
    Id_HandlerSocket.SSLOptions.Method := sslvTLSv1_2;
    Id_HandlerSocket.SSLOptions.SSLVersions := [sslvTLSv1_2];
    idHTTP1.IOHandler := Id_HandlerSocket;
    if (idHTTP1.Compressor = nil) or (not idHTTP1.Compressor.IsReady) then
      idHTTP1.Request.AcceptEncoding := 'identity'
    else
      idHTTP1.Request.AcceptEncoding := 'gzip,deflate,identity';
    idHTTP1.Request.BasicAuthentication := true;
    IdHTTP1.Request.UserAgent := OctopusUserAgent;
    IdHTTP1.Request.Username := FAPIKey;
    s := IdHTTP1.Get(url);
    if IdHTTP1.ResponseCode = 200 then
    begin
      result := true;
      FLastResponse := s;
      FLastFetched := now;
    end;
  finally
    Id_HandlerSocket.Free;
    if Assigned(IdHTTP1.Compressor) then IdHTTP1.Compressor.Free;
    IdHTTP1.Free;
  end;
end;

function TOctopus.getLastResponse: AnsiString;
begin
  if IncHour(FLastFetched, 4) < now then
    fetch(OctopusURL + 'v1/products/AGILE-18-02-21/' +
      'electricity-tariffs/E-1R-AGILE-18-02-21-N/standard-unit-rates/');
  result := FLastResponse
end;

end.