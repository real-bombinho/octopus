unit Octopus;

interface

uses System.SysUtils, System.DateUtils;

const
  OctopusURL = 'https://api.octopus.energy/';
  OctopusUserAgent = 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:12.0) '+
    'Gecko/20100101 Firefox/12.0';

type

  RRegion = record
  const
    EasternEngland = 'A';
    EastMidlands = 'B';
    London = 'C';
    MerseysideAndNorthernWales = 'D';
    WestMidlands = 'E';
    NorthEasternEngland = 'F';
    NorthWesternEngland = 'G';
    SouthernEngland = 'H';
    SouthEasternEngland = 'J';
    SouthernWales = 'K';
    SouthWesternEngland = 'L';
    Yorkshire = 'M';
    SouthernScotland = 'N';
    NorthernScotland = 'P';
  private
    FValue: char;
    function getCode: integer;
    procedure setCode(const Value: integer);
    function getName: String;
    procedure setCharacter(const Value: char);
  public
    property Character: char read FValue write setCharacter;
    property Code: integer read getCode write setCode;
    property Name: String read getName;
  end;

  TOctopus = class
  private
    FLastResponse: AnsiString;
    FLastFetched: TDateTime;
    FLastUnsuccessful: TDateTime;
    FLastResponseCode: integer;
    FAPIKey: AnsiString;
    FRegion: RRegion;
    FTariff: string;
    function fetch(const url: string): boolean;
    function getLastResponse: AnsiString;
  public
    property LastResponse: AnsiString read getLastResponse;
    property ResponseCode: integer read FLastResponseCode;
    property APIKey: AnsiString write FAPIKey;
    property Region: RRegion read FRegion;
    property Tariff: string read FTariff write FTariff;
    constructor Create(const Key: String; const region: char); overload;
    procedure Refresh;
  end;

implementation

uses IdHTTP, IdSSLOpenSSL,IdCompressorZLib;

const WaitIfFailed = 5;
      CacheHours = 4;
{ TOctopus }

constructor TOctopus.Create(const key: String; const region: char);
begin
  inherited Create;
  FAPIKey := key;
  FRegion.Character := region;
  FLastResponse := '';
  FLastFetched := 0;
  FLastUnsuccessful := 0;
  FTariff := 'AGILE-18-02-21';
end;

////////////////////////////////////////////////////////////////////////////////
//
// fetches API, if previously unsuccessful, it will fail further attempts for
//   [const WaitIfFailed] minutes and ResponseCode will be -1.
//
////////////////////////////////////////////////////////////////////////////////

function TOctopus.fetch(const url: string): boolean;
var Id_HandlerSocket : TIdSSLIOHandlerSocketOpenSSL;
    IdHTTP1: TIdHTTP;
    s: string;
begin
  result := false;
  if FLastUnsuccessful <> 0 then
    if IncMinute(FLastUnsuccessful, WaitIfFailed) < now then
    begin
      FLastResponseCode := -1;
      exit;
    end;
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
    FLastUnsuccessful := now;
    s := IdHTTP1.Get(url);
    FLastResponseCode := IdHTTP1.ResponseCode;
    if FLastResponseCode = 200 then
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
  FLastUnsuccessful := 0;
end;

////////////////////////////////////////////////////////////////////////////////
//
// getLastResponse uses the cached result if existing and not older than
// (const CacheHours)
//
////////////////////////////////////////////////////////////////////////////////

function TOctopus.getLastResponse: AnsiString;
begin
  if IncHour(FLastFetched, CacheHours) < now then
    Refresh;
  result := FLastResponse
end;

procedure TOctopus.Refresh;
begin
  fetch(OctopusURL + 'v1/products/' + FTariff + '/' +
      'electricity-tariffs/E-1R-' + FTariff + '-' + FRegion.Character +
      '/standard-unit-rates/');
end;

{ RRegion }

function RRegion.getCode: integer;
begin
  case FValue of
    'A':	result := 10;	// Eastern England
    'B':	result := 11;	// East Midlands
    'C':	result := 12;	// London
    'D':	result := 13;	// Merseyside and Northern Wales
    'E':	result := 14;	// West Midlands
    'F':	result := 15;	// North Eastern England
    'G':	result := 16;	// North Western England
    'H':	result := 20;	// Southern England
    'J':	result := 19;	// South Eastern England
    'K':	result := 21;	// Southern Wales
    'L':	result := 22;	// South Western England
    'M':	result := 23;	// Yorkshire
    'N':	result := 18;	// Southern Scotland
    'P':	result := 17;	// Northern Scotland
    else result := -1;
  end;
end;

function RRegion.getName: String;
begin
  case FValue of
    'A':	result := 'Eastern England';
    'B':	result := 'East Midlands';
    'C':	result := 'London';
    'D':	result := 'Merseyside and Northern Wales';
    'E':	result := 'West Midlands';
    'F':	result := 'North Eastern England';
    'G':	result := 'North Western England';
    'H':	result := 'Southern England';
    'J':	result := 'South Eastern England';
    'K':	result := 'Southern Wales';
    'L':	result := 'South Western England';
    'M':	result := 'Yorkshire';
    'N':	result := 'Southern Scotland';
    'P':	result := 'Northern Scotland';
    else result := 'Undefined';
  end;
end;

procedure RRegion.setCharacter(const Value: char);
begin
  if charInSet(Value, ['A'..'H', 'J'..'N', 'P']) then
    FValue := value
  else
  begin
    FValue := #0;
    raise Exception.Create('Invalid region character: ' + value);
  end;
end;

procedure RRegion.setCode(const Value: integer);
begin
  case Value of
    10:	FValue := EasternEngland;
    11:	FValue := EastMidlands;
    12:	FValue := London;
    13:	FValue := MerseysideAndNorthernWales;
    14:	FValue := WestMidlands;
    15:	FValue := NorthEasternEngland;
    16:	FValue := NorthWesternEngland;
    20:	FValue := SouthernEngland;
    19:	FValue := SouthEasternEngland;
    21:	FValue := SouthernWales;
    22:	FValue := SouthWesternEngland;
    23:	FValue := Yorkshire;
    18:	FValue := SouthernScotland;
    17:	FValue := NorthernScotland;
    else FValue := #0;
  end;
end;

end.
