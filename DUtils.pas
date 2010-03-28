unit DUtils;

{$I+}

interface

type
	{$IFDEF ACCURATE_TREAL}
		TReal = Double;
	{$ELSE}
		TReal = Single;
	{$ENDIF}

	TStringArray = array of String;

	TRGBAColor = packed record
	case Boolean of
		True: (R, G, B, A: Byte);
		False: (Color: LongWord);
	end;
	PRGBAColor = ^TRGBAColor;

const
	clGreyBase = $010101;

	NAN = 0/0;
	PosInfinity = +1/0;
	NegInfinity = -1/0;

//math
function InWord(R: TReal): Word;
procedure Swap(var A, B: LongWord); overload;
function MinNonZero(A, B: Integer): Integer;
function MotorolaDWord(I: LongWord): LongWord;
function MotorolaWord(I: Word): Word;

//dice/statistics
function D6(Dice: LongWord = 1): LongWord;
function Roll(Dice: LongWord = 1; DieSize: Integer = 6): LongWord;
function PoissonRoll: LongWord;

//string conversion
function IntAsStr(I: LongWord): String;
function StrAsInt(S: String): LongWord;
function StrToLStr(S: String): String;

//string manipulation
procedure Swap(var A, B: String); overload;
procedure BubbleSort(Strings: TStringArray);
function StrTokenize(S: String; Token: Char): TStringArray;
function InStrC(C: Char; S: String; StartIndex: Integer = 1): LongWord;
function InStrRC(C: Char; S: String; StartIndex: Integer = MAXINT): LongWord;
function StringReplaceC(const S: String; const OldChar, NewChar: Char): String;

//file manipulation
procedure DumpStringToFile(S, FN: String);
function DumpFileToString(FN: String): String;
function DumpFileNamesToStringArray(SearchPath: String): TStringArray;
function DumpFileNamesInBranchToStringArray(BasePath: String): TStringArray;





implementation

uses
	SysUtils, Math, MTRandomity, GLib2;

function InWord(R: TReal): Word;
begin
	if R <= 0 then
		Result := 0
	else if R >= 65535 then
		Result := 65535
	else
		Result := Round(R)
	;
end;

procedure Swap(var A, B: LongWord);
var
	C: LongWord;

begin
	C := A;
	A := B;
	B := C;
end;

function MinNonZero(A, B: Integer): Integer;
begin
	if A = 0 then
		Result := B
	else if B = 0 then
		Result := A
	else if A < B then
		Result := A
	else
		Result := B
	;
end;

function MotorolaDWord(I: LongWord): LongWord;
asm
	bswap EAX
end;

function MotorolaWord(I: Word): Word;
asm
	xchg AH, AL
end;



function D6(Dice: LongWord = 1): LongWord;
var
  I: Integer;

begin
  Result := Dice;
  for I := Dice-1 downto 0 do
    Inc(Result, RandN(6))
  ;
end;

function Roll(Dice: LongWord = 1; DieSize: Integer = 6): LongWord;
var
  I: Integer;

begin
  Result := Dice;
  for I := Dice-1 downto 0 do
    Inc(Result, RandN(DieSize))
  ;
end;

function PoissonRoll: LongWord;
begin
  Result := -Ceil(Log2(RandReal));
end;



function IntAsStr(I: LongWord): String;
begin
  SetString(Result, PChar(@I), 4);
end;

function StrAsInt(S: String): LongWord;
begin
  case Length(S) of
    0: Result := 0;
    1: Result := PByte(@S[1])^;
    2: Result := PWord(@S[1])^;
    else Result := PLongWord(@S[1])^; //3 works because non-empty strings are null-terminated
  end;
end;

function StrToLStr(S: String): String;
var
  L: Integer;

begin
  L := Length(S);
  SetString(Result, PChar(@L), 4);
  Result := Result + S;
end;



procedure Swap(var A, B: String);
var
	C: String;

begin
	C := A;
	A := B;
	B := C;
end;

procedure BubbleSort(Strings: TStringArray);
var
	I, J: Integer;
	bChanged: Boolean;

begin
	for I := Length(Strings) - 2 downto 0 do begin
		bChanged := False;
		for J := 0 to I do
			if Strings[J] > Strings[J + 1] then begin
				Swap(Strings[J], Strings[J + 1]);
				bChanged := True;
			end
		;
		if not bChanged then Break;
	end;
end;

function StrTokenize(S: String; Token: Char): TStringArray;
var
	I, ResultLen: Integer;

begin
	ResultLen := 0;
	repeat
		I := Pos(Token, S);
		if I = 0 then begin
			SetLength(Result, ResultLen + 1);
			Result[ResultLen] := S;
			//Inc(ResultLen);
			Exit;
		end;
		SetLength(Result, ResultLen + 1);
		Result[ResultLen] := Copy(S, 1, I - 1);
		Inc(ResultLen);
		S := Copy(S, I + 1, MAXINT);
	until False;
end;

function InStrC(C: Char; S: String; StartIndex: Integer = 1): LongWord;
var
	I: Integer;

begin
	for I := StartIndex to Length(S) do
		if S[I] = C then begin
			Result := I;
			Exit;
		end
	;

	Result := 0;
end;

function InStrRC(C: Char; S: String; StartIndex: Integer = MAXINT): LongWord;
var
	I: Integer;

begin
	I := Length(S);
	if StartIndex < I then I := StartIndex;
	for I := I downto 1 do
		if S[I] = C then
			Break
	;

	Result := I;
end;

function StringReplaceC(const S: String; const OldChar, NewChar: Char): String;
var
  I: Integer;

begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] = OldChar then
      Result[I] := NewChar
  ;
end;



procedure DumpStringToFile(S, FN: String);
var
	F: File;

begin
	Assign(F, FN);
	Rewrite(F, 1);
	BlockWrite(F, S[1], Length(S));
	Close(F);
end;

function DumpFileToString(FN: String): String;
var
	F: File;

begin
	Assign(F, FN);
	Reset(F, 1);
	SetString(Result, nil, FileSize(F));
	BlockRead(F, Result[1], Length(Result));
	Close(F);
end;

function DumpFileNamesToStringArray(SearchPath: String): TStringArray;
var
	Findee: TSearchRec;
	I: Integer;

begin
	SearchPath := IncludeTrailingPathDelimiter(SearchPath);

	I := 0;
	if FindFirst(SearchPath + '*', faAnyFile, Findee) = 0 then repeat
		if Findee.Name[1] = '.' then Continue; //Skip virtual dirs and control files like .htaccess
		SetLength(Result, I + 1);
		Result[I] := Findee.Name;
		if (Findee.Attr and faDirectory) <> 0 then Result[I] := IncludeTrailingPathDelimiter(Result[I]);
		Inc(I);
	until FindNext(Findee) <> 0;
	FindClose(Findee);
end;

function DumpFileNamesInBranchToStringArray(BasePath: String): TStringArray;
var
	Findee: TSearchRec;
	Dirs: TStringArray;
	ResultLen, DirsLen: Integer;
	SubPath: String;

begin
	BasePath := IncludeTrailingPathDelimiter(BasePath);
	SubPath := '';

	ResultLen := 0;
	DirsLen := 0;
	try
		repeat
			if FindFirst(BasePath + SubPath + '*', faAnyFile, Findee) = 0 then repeat
				if Findee.Name[1] = '.' then Continue; //Skip virtual dirs and control files like .htaccess
				if (Findee.Attr and faDirectory) = 0 then begin
					SetLength(Result, ResultLen);
					Result[ResultLen] := SubPath + Findee.Name;
					Inc(ResultLen);
				end
				else begin
					SetLength(Dirs, DirsLen + 1);
					Dirs[DirsLen] := IncludeTrailingPathDelimiter(SubPath + Findee.Name);
					Inc(DirsLen);
				end;
			until FindNext(Findee) <> 0;
			FindClose(Findee);

			if DirsLen = 0 then Break;

			Dec(DirsLen);
			SubPath := Dirs[DirsLen];
			SetLength(Dirs, DirsLen);
		until False;
	finally
		SetLength(Dirs, 0);
	end;
end;

end.
