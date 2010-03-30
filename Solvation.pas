unit Solvation;

interface

type
  TSolveLogProc = procedure (Equation: String) of object;

var
  SolveLog: TSolveLogProc;

function Solve(Equation: String): Double;

type
  TPresolvedVarData = record
    Nom: String;
    Value: Double;
  end;

var
  VarList: array of TPresolvedVarData;

implementation

uses
  Math,
  {$IFDEF Linux}
    NixRandomity,
  {$ELSE}
    MTRandomity,
  {$ENDIF}
  SysUtils, Classes;

function Roll(Dice: LongWord = 1; DieSize: Integer = 6): LongWord;
var
  I: Integer;

begin
  Result := Dice;
  for I := Dice-1 downto 0 do
    Inc(Result, RandN(DieSize))
  ;
end;

procedure TVarRec; begin end;

const
  NOpLevel = 5;

type
  TToken = record
    case IsOp: Boolean of
  True: (
    Op: Char;
  );
  False: (
    Value: Double;
  );
  end;

  TAT = array of TToken;

function Op2OpLevel(Op: Char): Integer;
begin
  case Op of
  '+', '-': Result := 0;
  '*', '/': Result := 1;
  '^': Result := 2;
  '''': Result := 3;
  '#': Result := 4;
  else Result := NOpLevel;
  end;
end;

function NewAT(Value: Double): TToken;
begin
  Result.IsOp := False;
  Result.Value := Value;
end;

{
function GetValue(X: TToken): Double;
begin
  if X.IsOp then
    raise EParserError.Create('Attempt to take value of operator "' + X.Op + '"')
  ;
  Result := X.Value;
end;
}

function PosNChar(SearchFor: array of Char; SearchIn: String): Integer;
var
  I: Integer;

begin
  for Result := 1 to Length(SearchIn) do
    for I := 0 to High(SearchFor) do
      if SearchIn[Result] = SearchFor[I] then
        Exit
  ;
  Result := 0;
end;

function RPosNChar(SearchFor: array of Char; SearchIn: String): Integer;
var
  I: Integer;

begin
  for Result := Length(SearchIn) downto 1 do
    for I := 0 to High(SearchFor) do
      if SearchIn[Result] = SearchFor[I] then
        Exit
  ;
  Result := 0;
end;

function ATCopy(A: TAT; Index, Len: Integer): TAT;
var
  I: Integer;

begin
  if LongWord(Index) + LongWord(Len) > LongWord(Length(A)) then
    Len := Length(A) - Index
  ;
  SetLength(Result, Len);
  for I := 0 to Len - 1 do
    Result[I] := A[Index + I]
  ;
end;

function StripChar(S: String; C: Char): String;
var
  I, J: Integer;

begin
  SetLength(Result, Length(S));
  J := 1;
  for I := 1 to Length(S) do
    if S[I] <> C then begin
      Result[J] := S[I];
      Inc(J);
    end
  ;
  SetLength(Result, J - 1);
end;

function BuildArray(LA: TAT; X: Double; RA: TAT): TAT;
var
  I: Integer;

begin
  SetLength(Result, Length(LA) + 1 + Length(RA));
  for I := 0 to High(LA) do
    Result[I] := LA[I]
  ;
  Result[Length(LA)] := NewAT(X);
  for I := 0 to High(RA) do
    Result[I + Length(LA) + 1] := RA[I]
  ;
end;

function EquationToStr(X: TAT): String;

  function TermToStr(XI: TToken): String;
  begin
    if XI.IsOp then
      Result := XI.Op
    else try
      Result := FloatToStr(XI.Value);
    except
      Result := '#?#';
    end;
  end;

var
  I: Integer;

begin
  if High(X) < 0 then begin
    Result := '';
    Exit;
  end;
  Result := TermToStr(X[0]);

  for I := 1 to High(X) do
    Result := Result + ' ' + TermToStr(X[I])
  ;
end;

procedure HandleUnarySign(var Equation: TAT);
var
  I, J: Integer;
  
begin
  for I := High(Equation) - 1 downto 0 do
    if (Equation[I].IsOp)
    and (Equation[I].Op in ['+', '-'])
    and (
      (I = 0)
      or ((Equation[I - 1].IsOp) and (Equation[I - 1].Op <> ')'))
    ) then begin
      if Equation[I].Op = '-' then
        Equation[I] := NewAT(-Equation[I + 1].Value)
      else
        Equation[I] := Equation[I + 1]
      ;
      for J := I + 1 to High(Equation) - 1 do
        Equation[J] := Equation[J + 1]
      ;
      Equation := ATCopy(Equation, 0, High(Equation));
    end
  ;
end;

function SolveAT(Equation: TAT): Double;
var
  I, J, ThisOpLevel, OpLevel: Integer;
  A, B: Double;

begin
  if Assigned(SolveLog) then SolveLog(':' + EquationToStr(Equation));

  if High(Equation) = -1 then raise EParserError.Create('"" is not a valid floating point value');

  if High(Equation) = 0 then begin
    if Equation[0].IsOp then raise EParserError.Create('Equation "' + EquationToStr(Equation) + '" contained subequation with no terms');
    Result := Equation[0].Value;
    Exit;
  end;

  J := -1;
  for I := 0 to High(Equation) do
    if Equation[I].IsOp then begin
      if Equation[I].Op = '(' then
        J := I
      else if Equation[I].Op = ')' then begin
        if J = -1 then raise EParserError.Create('Unmatched close-parenthesis in "' + EquationToStr(Equation) + '"');
        Result := SolveAT(BuildArray(
          ATCopy(Equation, 0, J),
          SolveAT(ATCopy(Equation, J + 1, I - J - 1)),
          ATCopy(Equation, I + 1, MAXINT)
        ));
        Exit;
      end;
    end
  ;
  if J <> -1 then raise EParserError.Create('Unmatched open-parenthesis in "' + EquationToStr(Equation) + '"');

  HandleUnarySign(Equation); //This little inanity prevents an internal compiler error

  OpLevel := NOpLevel;
  for I := High(Equation) downto 0 do
    if Equation[I].IsOp then begin
      ThisOpLevel := Op2OpLevel(Equation[I].Op);
      if ThisOpLevel < OpLevel then begin
        J := I;
        OpLevel := ThisOpLevel;
        if OpLevel = 0 then Break;
      end;
    end
  ;

  if OpLevel = NOpLevel then begin
    //raise EParserError.Create('"' + EquationToStr(Equation) + '"contained multiple terms and no operators');
    if Equation[0].IsOp then raise EParserError.Create('Attempt to take value of operator "' + Equation[0].Op + '"');
    Result := Equation[0].Value;
    for I := 1 to High(Equation) do
      if Equation[I].IsOp then
        raise EParserError.Create('Attempt to take value of operator "' + Equation[0].Op + '"')
      else
        Result := Result * Equation[I].Value
    ;
    Exit;
  end;

  A := SolveAT(ATCopy(Equation, 0, J));
  B := SolveAT(ATCopy(Equation, J + 1, MAXINT));
  case Equation[J].Op of
    '+': Result := A + B;
    '-': Result := A - B;
    '*': Result := A * B;
    '/': Result := A / B;
    '^': Result := Power(A, B);
    '''': Result := Roll(Round(A), Round(B));
    '#': Result := A * Power(10, B);
    else raise EParserError.Create('operator "' + Equation[J].Op + '" encountered');
  end;
end;

//TokToFloat is similar to StrToFloat, but it (sort of) handles extra radix formats, and it resolves var names.
function TokToFloat(Tok: String): Real;
var
  L, Radix, I, J: Integer;
  AntiRadix, Fractional: Real;

begin
  L := Length(Tok);
  case Tok[1] of
    'A'..'Z', 'a'..'z': begin
      Tok := UpperCase(Tok);
      for I := 0 to High(VarList) do
        if VarList[I].Nom = Tok then begin
          Result := VarList[I].Value;
          Exit;
        end;
      raise EParserError.Create('Var ' + Tok + ' not found.');
    end;
    '$': begin
      Radix := 16;
      AntiRadix := 1/16;
      I := 2;
    end;
    else case Tok[L] of
      'h', 'H': begin //Not particularly usable
        Radix := 16;
        AntiRadix := 1/16;
        I := 1;
        Dec(L);
        SetLength(Tok, L);
      end;
      'b', 'B': begin //Not particularly usable
        Radix := 2;
        AntiRadix := 1/2;
        I := 1;
        Dec(L);
        SetLength(Tok, L);
      end;
      else begin
        Radix := 10;
        AntiRadix := 1/10;
        I := 1;
      end;
    end;
  end;

  Result := 0;
  repeat
    case Tok[I] of
      '0'..'9': Result := Result * Radix + (Byte(Tok[I]) and $F);
      'A'..'F',
      'a'..'f': Result := Result * Radix + (Byte(Tok[I]) and $7 + 9);
                //A = 41h, 41h and 7h = 1h, 1h + 9 = 10
      '.':      Break;
      else      raise EConvertError.Create('"' + Tok + '" contains invalid character "' + Tok[I] + '".');
    end;
    Inc(I);
    if I > L then Exit;
  until False;

  //Scan right-to-left for the fractional portion
  Fractional := 0;
  J := L;
  repeat
    case Tok[J] of
      '0'..'9': Fractional := (Fractional + (Byte(Tok[J]) and $F)) * AntiRadix;
      'A'..'F',
      'a'..'f': Fractional := (Fractional + (Byte(Tok[J]) and $7 + 9)) * AntiRadix;
                //A = 41h, 41h and 7h = 1h, 1h + 9 = 10
      '.':      Break;
      else      raise EConvertError.Create('"' + Tok + '" contains invalid character "' + Tok[I] + '".');
    end;
    Dec(J);
  until J < I;
  Result := Result + Fractional;
end;

function Tokenize(S: String): TAT;
var
  I, L: Integer;
  Buf: String;

begin
  SetLength(Result, 0);
  L := 0;

  if S = '' then Exit;

  while Length(S) <> 0 do begin
    I := PosNChar(['+', '-', '*', '/', '^', '''', '#', '(', ')'], S);
    if I = 0 then begin
      SetLength(Result, L + 1);
      Result[L] := NewAT(TokToFloat(S));
      //Inc(L);
      Break;
    end
    else begin
      Buf := Copy(S, 1, I - 1);
      if Buf <> '' then begin
        SetLength(Result, L + 2);
        Result[L] := NewAT(TokToFloat(Buf));
        Inc(L);
      end
      else
        SetLength(Result, L + 1)
      ;
      Result[L].IsOp := True;
      Result[L].Op := S[I];
      Inc(L);

      S := Copy(S, I + 1, MAXINT);
    end;
  end;
end;

function Solve(Equation: String): Double;
begin
  Result := SolveAT(Tokenize(StripChar(Equation, ' ')));
end;

end.
