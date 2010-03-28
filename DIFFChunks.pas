unit DIFFChunks;

interface

uses
  SysUtils, Classes;

type
  TDIFFChunk = class;

  TPHeaderEntry = ^THeaderEntry;
  THeaderEntry = record
    Nom,
    Dat: String;
  end;
  THeaderEntries = array of THeaderEntry;
  TDIFFChunks = array of TDIFFChunk;

  TDIFFChunk = class
  protected
    fTagStr: String;
    procedure SetTagStr(const Value: String);
    function GetHeaderByName(Nom: String): String;
    procedure SetHeaderByName(Nom: String; const Value: String);
  public
    property TagStr: String read fTagStr write SetTagStr;
  public
    Header: THeaderEntries;
    Child: TDIFFChunks;
    SpecData: String;

    constructor Create; virtual;
    constructor CreateFromFile(FN: String); virtual;
    constructor CreateFromStream(S: TStream); virtual;
    constructor CreateFromString(S: String); virtual;
    destructor Destroy; override;
    procedure LoadFromFile(FN: String); virtual;
    procedure LoadFromStream(S: TStream); virtual;
    procedure LoadFromString(S: String); virtual;
    procedure SaveToFile(FN: String); virtual;
    procedure SaveToStream(S: TStream); virtual;
    function SaveToString: String; virtual;
    function AddHeader(Nom, Dat: String): Integer; virtual;
    function AddChild(NewChild: TDIFFChunk): Integer; virtual;
    function AddNewChild: TDIFFChunk; virtual;
    property HeaderByName[Nom: String]: String read GetHeaderByName write SetHeaderByName;
    function FindHeaderByName(Nom: String): TPHeaderEntry; virtual;
    procedure DeleteHeaderByName(Nom: String); virtual;
  end;

  EDIFFError = class(Exception);
  EDIFFBufferError = class(EDIFFError);
  EDIFFParseError = class(EDIFFError);

function PackTag(Nom: String; bChildList: Boolean = False; bHeaderList: Boolean = False): LongWord;
procedure UnpackTag(Tag: LongWord; var Nom: String; var bChildList, bHeaderList: Boolean);

function HasChunk(S: String): Boolean;
function ExtractChunkStr(var S: String): String;
function ExtractChunk(var S: String): TDIFFChunk;





implementation

uses
  DUtils;

type
  PLongWord = ^LongWord;
  TDummy = class procedure Nop; end;

const
  DTE2ANSI: array[0..$3F] of Char =
     #0' ()[]\|/?!•;:,.'
    + '0123456789ABCDEF'
    + 'GHIJKLMNOPQRSTUV'
    + 'WXYZ+±-=~~~~~~~~'
  ;

var
  ANSI2DTE: array[Char] of Byte;

function PackTag(Nom: String; bChildList: Boolean = False; bHeaderList: Boolean = False): LongWord;
var
  I: Integer;

begin
  if Length(Nom) <> 5 then raise EDIFFParseError.Create('DIFF tag must be 5 characters; cannot pack from ' + IntToStr(Length(Nom)) + '-char string "' + Nom + '".');

  Result := 0;
  for I := 5 downto 1 do
    Result := (Result shl 6) or ANSI2DTE[Nom[I]]
  ;

  Result := Result shl 1;
  if bChildList then Result := Result or 1;

  Result := Result shl 1;
  if bHeaderList then Result := Result or 1;
end;

procedure UnpackTag(Tag: LongWord; var Nom: String; var bChildList, bHeaderList: Boolean);
var
  I: Integer;

begin
  bHeaderList := (Tag and 1) <> 0;
  Tag := Tag shr 1;

  bChildList := (Tag and 1) <> 0;
  Tag := Tag shr 1;

  SetString(Nom, nil, 5);
  for I := 1 to 5 do begin
    Nom[I] := DTE2ANSI[Tag and $3F];
    Tag := Tag shr 6;
  end;
end;

function HasChunk(S: String): Boolean;
var
  pBuf: PLongWord;
  BytesLeft: LongWord;

begin
  Result := False;

  BytesLeft := Length(S);
  if BytesLeft < 8 then Exit;
  Dec(BytesLeft, 8);
  pBuf := PLongWord(PChar(S));
  Inc(pBuf);
  if pBuf^ > BytesLeft then Exit;

  Result := True;
end;

function ExtractChunkStr(var S: String): String;
var
  pBuf: PLongWord;
  L, BytesLeft: LongWord;

begin
  Result := '';

  BytesLeft := Length(S);
  if BytesLeft < 8 then Exit;
  Dec(BytesLeft, 8);
  pBuf := PLongWord(PChar(S));
  Inc(pBuf);
  L := pBuf^;
  if L > BytesLeft then Exit;

  Result := Copy(S, 1, 8 + L);
  S := Copy(S, 9 + L, MAXINT);
end;

function ExtractChunk(var S: String): TDIFFChunk;
var
  ChunkBuf: String;

begin
  Result := nil;

  ChunkBuf := ExtractChunkStr(S);

  if Length(ChunkBuf) = 0 then Exit;

  Result := TDIFFChunk.CreateFromString(ChunkBuf);
end;

{ TDIFFChunk }

function TDIFFChunk.AddChild(NewChild: TDIFFChunk): Integer;
begin
  Result := Length(Child);
  SetLength(Child, Result + 1);
  Child[Result] := NewChild;
end;

function TDIFFChunk.AddHeader(Nom, Dat: String): Integer;
begin
  Result := Length(Header);
  SetLength(Header, Result + 1);
  Header[Result].Nom := Nom;
  Header[Result].Dat := Dat;
end;

function TDIFFChunk.AddNewChild: TDIFFChunk;
begin
  Result := TDIFFChunk(ClassType.Create);
  AddChild(Result);
end;

constructor TDIFFChunk.Create;
begin
  fTagStr := #0#0#0#0#0;
end;

constructor TDIFFChunk.CreateFromFile(FN: String);
begin
  Create;
  LoadFromFile(FN);
end;

constructor TDIFFChunk.CreateFromStream(S: TStream);
begin
  Create;
  LoadFromStream(S);
end;

constructor TDIFFChunk.CreateFromString(S: String);
begin
  Create;
  LoadFromString(S);
end;

procedure TDIFFChunk.DeleteHeaderByName(Nom: String);
var
  H, I: Integer;

begin
  H := High(Header);
  for I := H downto 0 do
    if Header[I].Nom = Nom then begin
      if I < H then begin
        Header[I] := Header[H]; //For garbage collection.
        Move(Header[I + 1], Header[I], SizeOf(Header[I]) * (H - I));
      end;
      SetLength(Header, H);
      Dec(H);
    end
  ;
end;

destructor TDIFFChunk.Destroy;
var
  I: Integer;

begin
  for I := 0 to High(Child) do
    FreeAndNil(Child[I])
  ;
  SetLength(Child, 0);

  inherited;
end;

function TDIFFChunk.FindHeaderByName(Nom: String): TPHeaderEntry;
var
  I: Integer;

begin
  for I := 0 to High(Header) do
    if Header[I].Nom = Nom then begin
      Result := @Header[I];
      Exit;
    end
  ;
  Result := nil;
end;

function TDIFFChunk.GetHeaderByName(Nom: String): String;
var
  ThatHeader: TPHeaderEntry;

begin
  ThatHeader := FindHeaderByName(nom);
  if ThatHeader = nil then
    Result := ''
  else
    Result := ThatHeader.Dat
  ;
end;

{
procedure TDIFFChunk.LoadFromFile(FN: String);
var
  FS: TDFileStream;

begin
  FS := TDFileStream.Create(FN, dfOpenOrFail + dfRead);
  try
    LoadFromStream(FS);
  finally
    FS.Free;
  end;
end;
}

procedure TDIFFChunk.LoadFromFile(FN: String);
var
	Content: String;

begin
	Content := DumpFileToString(FN);
	LoadFromString(Content);
end;

procedure TDIFFChunk.LoadFromStream(S: TStream);
var
  Tag, L, BytesLeft: LongWord;
  RollbackPos: Integer;
  bDummy: Boolean;
  ChunkStr: String;

begin
  RollbackPos := S.Position;
  try
    BytesLeft := S.Size - RollbackPos;

    if BytesLeft < 8 then raise EDIFFBufferError.Create('Error loading DIFF chunk: only ' + IntToStr(BytesLeft) + ' bytes were available.');

    S.Read(Tag, 4); Dec(BytesLeft, 4);
    S.Read(L, 4); Dec(BytesLeft, 4);
    if L > BytesLeft then begin
      UnpackTag(Tag, ChunkStr, bDummy, bDummy);
      raise EDIFFBufferError.Create('Claimed payload was ' + IntToStr(L) + ' bytes, but only ' + IntToStr(BytesLeft) + ' bytes were available. (During load of ' + ChunkStr + ' chunk.)');
    end;
    SetLength(ChunkStr, 8 + L);
    S.Position := RollbackPos;
    S.Read(ChunkStr[1], Length(ChunkStr));

    LoadFromString(ChunkStr);

  except
    S.Position := RollbackPos;

    raise;
  end;
end;

procedure TDIFFChunk.LoadFromString(S: String);
var
  TagStr: String;
  Header: THeaderEntries;
  Child: TDIFFChunks;
  SpecData: String;

  BytesLeft, Index: LongWord;
  InnerBytesLeft, InnerIndex: LongWord;
  I, L: LongWord;
  bChildList, bHeaderList: Boolean;
  ChildrenStr: String;
  ChildrenStream: TStringStream;

begin
  BytesLeft := Length(S);
  if BytesLeft < 8 then raise EDIFFBufferError.Create('Error loading DIFF chunk: only ' + IntToStr(BytesLeft) + ' bytes were available.');
  Index := 1;
  ChildrenStream := nil;

  try
    I := PLongWord(@S[Index])^; Inc(Index, 4); Dec(BytesLeft, 4);
    UnpackTag(I, TagStr, bChildList, bHeaderList);
    L := PLongWord(@S[Index])^; Inc(Index, 4); Dec(BytesLeft, 4);
    if L > BytesLeft then raise EDIFFBufferError.Create('Claimed payload was ' + IntToStr(L) + ' bytes, but only ' + IntToStr(BytesLeft) + ' bytes were available. (During load of ' + TagStr + ' chunk.)');
    S := Copy(S, Index, L);
    BytesLeft := Length(S);
    Index := 1;

    if bHeaderList then begin
      if 8 > BytesLeft then raise EDIFFBufferError.Create('Chunk claimed to have a header, but only ' + IntToStr(BytesLeft) + ' bytes were available. (During load of ' + TagStr + ' chunk.)');
      L := PLongWord(@S[Index])^; Inc(Index, 4); Dec(BytesLeft, 4);
      if L > BytesLeft then raise EDIFFBufferError.Create('Claimed header was ' + IntToStr(L) + ' bytes, but only ' + IntToStr(BytesLeft) + ' bytes were available. (During load of ' + TagStr + ' chunk.)');
      InnerBytesLeft := L;
      InnerIndex := Index;
      Inc(Index, L); Dec(BytesLeft, L);

      L := PLongWord(@S[InnerIndex])^; Inc(InnerIndex, 4); Dec(InnerBytesLeft, 4);
      SetLength(Header, L);
      if L <> 0 then begin
        FillChar(Header[0], L * 8, 0);
        for I := 0 to L - 1 do begin
          L := PLongWord(@S[InnerIndex])^; Inc(InnerIndex, 4); Dec(InnerBytesLeft, 4);
          if L > InnerBytesLeft then raise EDIFFBufferError.Create('Claimed header name was ' + IntToStr(L) + ' bytes, but only ' + IntToStr(InnerBytesLeft) + ' bytes were available in the header. (During load of ' + TagStr + ' chunk.)');
          SetString(Header[I].Nom, @S[InnerIndex], L); Inc(InnerIndex, L); Dec(InnerBytesLeft, L);

          L := PLongWord(@S[InnerIndex])^; Inc(InnerIndex, 4); Dec(InnerBytesLeft, 4);
          if L > InnerBytesLeft then raise EDIFFBufferError.Create('Claimed header data was ' + IntToStr(L) + ' bytes, but only ' + IntToStr(InnerBytesLeft) + ' bytes were available in the header. (During load of ' + TagStr + ' chunk.)');
          SetString(Header[I].Dat, @S[InnerIndex], L); Inc(InnerIndex, L); Dec(InnerBytesLeft, L);
        end;
      end;
    end;

    if bChildList then begin
      if 8 > BytesLeft then raise EDIFFBufferError.Create('Chunk claimed to have a chunk list, but only ' + IntToStr(BytesLeft) + ' bytes were available. (During load of ' + TagStr + ' chunk.)');
      L := PLongWord(@S[Index])^; Inc(Index, 4); Dec(BytesLeft, 4);
      if L > BytesLeft then raise EDIFFBufferError.Create('Claimed chunk list was ' + IntToStr(L) + ' bytes, but only ' + IntToStr(BytesLeft) + ' bytes were available. (During load of ' + TagStr + ' chunk.)');
      InnerBytesLeft := L;
      InnerIndex := Index;
      Inc(Index, L); Dec(BytesLeft, L);

      L := PLongWord(@S[InnerIndex])^; Inc(InnerIndex, 4); Dec(InnerBytesLeft, 4);
      SetLength(Child, L);
      if L <> 0 then begin
        FillChar(Child[0], L * 4, 0);
        SetString(ChildrenStr, @S[InnerIndex], InnerBytesLeft);
        ChildrenStream := TStringStream.Create(ChildrenStr);
        ChildrenStr := '';
        for I := 0 to L - 1 do
          Child[I] := TDIFFChunk.CreateFromStream(ChildrenStream)
        ;
        ChildrenStream.Free;
      end;
    end;

    if BytesLeft = 0 then
      SpecData := ''
    else
      SetString(SpecData, @S[Index], BytesLeft)
    ;

    Self.fTagStr := TagStr;
    Self.Header := Header;
    Self.Child := Child;
    Self.SpecData := SpecData;

  except
    SetLength(Header, 0);
    for I := 0 to High(Child) do FreeAndNil(Child[I]);
    SetLength(Child, 0);
    FreeAndNil(ChildrenStream);

    raise;
  end;
end;

{
procedure TDIFFChunk.SaveToFile(FN: String);
var
  FS: TDFileStream;

begin
  FS := TDFileStream.Create(FN, dfCreateOrReplace + dfWrite);
  try
    SaveToStream(FS);
  finally
    FS.Free;
  end;
end;
}

procedure TDIFFChunk.SaveToFile(FN: String);
var
	Content: String;

begin
	Content := SaveToString;
	DumpStringToFile(Content, FN);
end;

procedure TDIFFChunk.SaveToStream(S: TStream);
var
  Buf: String;
begin
  Buf := SaveToString;
  S.Write(Buf[1], Length(Buf));
  Buf := '';
end;

function TDIFFChunk.SaveToString: String;
var
  HeadStr, ChildStr: String;
  I: Integer;
  bChildList, bHeaderList: Boolean;

begin
  bChildList := Length(Child) <> 0;
  bHeaderList := Length(Header) <> 0;

  if not bHeaderList then
    HeadStr := ''
  else begin
    HeadStr := IntAsStr(Length(Header));
    for I := 0 to High(Header) do
      HeadStr := HeadStr + StrToLStr(Header[I].Nom) + StrToLStr(Header[I].Dat)
    ;
    HeadStr := StrToLStr(HeadStr);
  end;

  if not bChildList then
    ChildStr := ''
  else begin
    ChildStr := IntAsStr(Length(Child));
    for I := 0 to High(Child) do
      ChildStr := ChildStr + Child[I].SaveToString;
    ;
    ChildStr := StrToLStr(ChildStr);
  end;

  Result := IntAsStr(PackTag(fTagStr, bChildList, bHeaderList)) + StrToLStr(HeadStr + ChildStr + SpecData);
end;

procedure TDIFFChunk.SetHeaderByName(Nom: String; const Value: String);
var
  ThatHeader: TPHeaderEntry;

begin
  ThatHeader := FindHeaderByName(nom);
  if ThatHeader = nil then
    AddHeader(Nom, Value)
  else
    ThatHeader.Dat := Value
  ;
end;

procedure TDIFFChunk.SetTagStr(const Value: String);
begin
  if Length(Value) <> 5 then raise EDIFFParseError.Create('DIFF tag must be 5 characters; cannot set to ' + IntToStr(Length(Value)) + '-char string "' + Value + '".');
  fTagStr := Value;
end;





{ TDummy }

procedure TDummy.Nop;
begin end;

{ Initialization }

procedure DoInitialization;
var
  I: Integer;

begin
  for I := 0 to $FF do ANSI2DTE[Char(I)] := 0;
  for I := 0 to $3F do
    ANSI2DTE[DTE2ANSI[I]] := I
  ;
end;

initialization
  DoInitialization;
end.
