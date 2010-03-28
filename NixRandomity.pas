unit NixRandomity;

interface

function RandDWord: LongWord;
function RandGauss: Double; //StdDev = 1, Mean = 0; for arbitrary bell curves, use (Mean + StdDev * RandGauss)
function RandReal: Double; //.00000000 to .FFFFFFFF
function RandBipolar: Double;
function RandN(N: LongWord): LongWord; //0 to N-1
function RandWord: Word;
function RandByte: Byte;
function RandNybble: Byte;
function RandBit: Boolean;





implementation

const
  NAN: Double = 0/0; //Sentinel for GaussBuf.

var
	URandomFil: File of LongWord;
	WordBuf, ByteBuf, NybbleBuf, BitBuf: LongWord;
	GaussBuf: Double = 0/0; //Using the const doesn't work for some reason.
	WordN: Integer = 0;
	ByteN: Integer = 0;
	NybbleN: Integer = 0;
	BitN: Integer = 0;

function RandDWord: LongWord;
begin
	Read(URandomFil, Result);
end;

function RandWord: Word;
begin
  if WordN = 0 then begin
    WordBuf := RandDWord;
    Result := WordBuf;
    WordBuf := WordBuf shr 16;
    WordN := 1;
  end
  else begin
    Result := WordBuf;
    WordBuf := WordBuf shr 16;
    Dec(WordN);
  end;
end;

function RandByte: Byte;
begin
  if ByteN = 0 then begin
    ByteBuf := RandDWord;
    Result := ByteBuf;
    ByteBuf := ByteBuf shr 8;
    ByteN := 3;
  end
  else begin
    Result := ByteBuf;
    ByteBuf := ByteBuf shr 8;
    Dec(ByteN);
  end;
end;

function RandNybble: Byte;
begin
  if NybbleN = 0 then begin
    NybbleBuf := RandDWord;
    Result := NybbleBuf;
    NybbleBuf := NybbleBuf shr 4;
    NybbleN := 7;
  end
  else begin
    Result := NybbleBuf;
    NybbleBuf := NybbleBuf shr 4;
    Dec(NybbleN);
  end;
  Result := Result and $F;
end;

function RandBit: Boolean;
begin
  if BitN = 0 then begin
    BitBuf := RandDWord;
    Result := (BitBuf and 1) <> 0;
    BitBuf := BitBuf shr 1;
    BitN := 31;
  end
  else begin
    Result := (BitBuf and 1) <> 0;
    BitBuf := BitBuf shr 1;
    Dec(BitN);
  end;
end;

//Returns a roughly-evenly distributed value < N (unless N=0, then returns 0)
function RandN(N: LongWord): LongWord;
asm
  PUSH EAX
  CALL RandDWord
  POP EDX
  MUL EDX
  MOV EAX, EDX
end;

function RandGauss: Double;
var
  A, B, S: Double;
  NANBits: Int64 absolute NAN;
  BufBits: Int64 absolute GaussBuf;

begin
  if BufBits = NANBits then begin
    repeat
      repeat A := RandReal; until A <> 0; A := 2 * A - 1;
      repeat B := RandReal; until B <> 0; B := 2 * B - 1;
      S := A*A + B*B;
    until (S > 0) and (S < 1);
    S := Sqrt(-2*Ln(S)/S);
    Result := S * A;
    GaussBuf := S * B;
  end
  else begin
    Result := GaussBuf;
    GaussBuf := NAN;
  end;
end;

function RandReal: Double;
var
  RB: packed record
    BittyBits: Word;
    LoadLoc: LongWord;
    ExpyBits: Word;
  end absolute Result;
  RI: Int64 absolute Result;

begin
  RI := 0;
  RB.LoadLoc := RandDWord;
  RB.ExpyBits := $3FF;
  RI := RI shl 4;
  Result := Result - 1;
end;

function RandBipolar: Double;
var
  RB: packed record
    BittyBits: Word;
    LoadLoc: LongWord;
    ExpyBits: Word;
  end absolute Result;
  RI: Int64 absolute Result;

begin
  RI := 0;
  RB.LoadLoc := RandDWord;
  RB.ExpyBits := $400;
  RI := RI shl 4;
  Result := Result - 3;
end;

initialization
		Assign(URandomFil, '/dev/urandom');
		Reset(URandomFil, 1);
finalization
	Close(URandomFil);
end.
