unit MTRandomity;

{
  ABSTRACT
    Delphi adaptation of Mersenne Twister pseudorandom number generator.
    Original at <http://www.math.keio.ac.jp/~matumoto/emt.html>.
    The Random function in Delphi doesn't properly randomize the lower bits if the range is a power of 2, and I usually use a random function for power-of-2 ranges; the Mersenne Twister doesn't have this problem. It's slower to initialize, however.

  USAGE
    Add "uses MTRandomity" to your program/unit, usually in the implementation section.
    To initialize, call either RandDWordRandSetup or RandDWordSetup; RandDWordRandSetup uses a seed based on milliseconds since midnight. If you don't initialize, RandDWord will do it for you by calling RandDWordRandSetup.
    To get a random bitmask, call RandDWord and mask it down as needed. If you need a range that isn't a power of 2, mod it or use the existing random function.
}

{$Q-}

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

function RandDWordRandSetup: LongWord;
procedure RandDWordSetup(Seed: LongWord);

implementation

uses
  Windows;

const
  NAN: Double = 0/0; //Sentinel for GaussBuf.

  //Period parameters
  N = 624;
  M = 397;
  MATRIX_A = $9908b0df;   // constant vector a
  UPPER_MASK = $80000000; // most significant w-r bits
  LOWER_MASK = $7fffffff; // least significant r bits

  //Tempering parameters
  TEMPERING_MASK_B = $9d2c5680;
  TEMPERING_MASK_C = $efc60000;

function TEMPERING_SHIFT_U(Y: LongWord): LongWord; begin Result := Y shr 11; end;
function TEMPERING_SHIFT_S(Y: LongWord): LongWord; begin Result := Y shl  7; end;
function TEMPERING_SHIFT_T(Y: LongWord): LongWord; begin Result := Y shl 15; end;
function TEMPERING_SHIFT_L(Y: LongWord): LongWord; begin Result := Y shr 18; end;

var
  mt: array[0..N-1] of LongWord; // the array for the state vector
  MTI: Integer = N + 1; // mti=N+1 means mt[N] is not initialized
  mag01: array[0..1] of LongWord = ($0, MATRIX_A); // mag01[x] = x * MATRIX_A  for x=0,1
  WordBuf, ByteBuf, NybbleBuf, BitBuf: LongWord;
  GaussBuf: Double = 0/0;
  WordN: Integer = 0;
  ByteN: Integer = 0;
  NybbleN: Integer = 0;
  BitN: Integer = 0;

function RandDWord: LongWord;
var
  Y: LongWord;
  kk: Integer;

begin
    if (MTI >= N) then begin // generate N words at one time

        //If RandSetup has not been called, a random initial seed is used
        if MTI = N + 1 then
            //RandDWordSetup(4357)
            RandDWordRandSetup
        ;

        for kk := 0 to N - M - 1 do begin
            Y := (mt[kk] and UPPER_MASK) or (mt[kk + 1] and LOWER_MASK);
            mt[kk] := mt[kk + M] xor (Y shr 1) xor mag01[y and $1];
        end;
        for kk := N - M to N-2 do begin
            Y := (mt[kk] and UPPER_MASK) or (mt[kk + 1] and LOWER_MASK);
            mt[kk] := mt[kk + (M - N)] xor (Y shr 1) xor mag01[y and $1];
        end;
        Y := (mt[N - 1] and UPPER_MASK) or (mt[0] and LOWER_MASK);
        MT[N - 1] := mt[M - 1] xor (Y shr 1) xor mag01[y and $1];

        mti := 0;
    end;

    Y := MT[MTI];
    Inc(MTI);
    Y := Y xor TEMPERING_SHIFT_U(Y);
    Y := Y xor (TEMPERING_SHIFT_S(Y) and TEMPERING_MASK_B);
    Y := Y xor (TEMPERING_SHIFT_T(Y) and TEMPERING_MASK_C);
    Y := Y xor TEMPERING_SHIFT_L(Y);

    Result := Y;
end;

function RandDWordRandSetup: LongWord;
var
  ST: TSystemTime;

begin
  GetSystemTime(ST);
  Result := ((ST.wHour * 60 + ST.wMinute) * 60 + ST.wSecond) * 1000 + ST.wMilliseconds;
  RandDWordSetup(Result);
end;

// initializing the array with a NONZERO seed
procedure RandDWordSetup(Seed: LongWord);
var
  lMTI: Integer;
begin
    // setting initial seeds to mt[N] using
    // the generator Line 25 of Table 1 in
    // [KNUTH 1981, The Art of Computer Programming
    //    Vol. 2 (2nd Ed.), pp102]
    mt[0] := Seed and $ffffffff;
    for lMTI := 1 to N - 1 do
        mt[lMTI] := (69069 * mt[lMTI-1]) and $ffffffff
    ;
    MTI := N;

    GaussBuf := NAN;
    ByteN := 0;
    NybbleN := 0;
    BitN := 0;
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

end.
