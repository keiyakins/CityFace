unit SDLKeyDatas;

interface

uses
	SDL;

type
	TSDLKeyEvent = procedure (Key: TSDLKey) of object;
	TBuckyKey = (bkShift, bkCtrl, bkAlt);
	TBuckyState = set of TBuckyKey;

	TKeyData = class
	protected
		FKeyDown: array[0..511] of Boolean;
		FOnKeyDown: array[0..511] of TSDLKeyEvent;

		function GetKeyDown(Index: Integer): Boolean;
		procedure SetKeyDown(Index: Integer; const Value: Boolean);
		function GetOnKeyDown(Index: Integer): TSDLKeyEvent;
		procedure SetOnKeyDown(Index: Integer; const Value: TSDLKeyEvent);
		function GetBuckyState: TBuckyState;
	public
		property KeyDown[Index: Integer]: Boolean read GetKeyDown write SetKeyDown; default;
		property OnKeyDown[Index: Integer]: TSDLKeyEvent read GetOnKeyDown write SetOnKeyDown;
		property BuckyState: TBuckyState read GetBuckyState;
	end;

const
	SDLK_KP_Up = SDLK_KP8;
	SDLK_KP_Down = SDLK_KP2;
	SDLK_KP_Left = SDLK_KP4;
	SDLK_KP_Right = SDLK_KP6;
	SDLK_KP_Home = SDLK_KP7;
	SDLK_KP_End = SDLK_KP1;
	SDLK_KP_PgUp = SDLK_KP9;
	SDLK_KP_PgDn = SDLK_KP3;



implementation

uses
	SysUtils, Classes;

{ TKeyData }

function TKeyData.GetBuckyState: TBuckyState;
begin
	Result := [];
	if FKeyDown[SDLK_LSHIFT] or FKeyDown[SDLK_RSHIFT] then Include(Result, bkShift);
	if FKeyDown[SDLK_LCTRL ] or FKeyDown[SDLK_RCTRL ] then Include(Result, bkCtrl );
	if FKeyDown[SDLK_LALT  ] or FKeyDown[SDLK_RALT  ] then Include(Result, bkAlt  );
end;

function TKeyData.GetKeyDown(Index: Integer): Boolean;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FKeyDown[Index];
end;

function TKeyData.GetOnKeyDown(Index: Integer): TSDLKeyEvent;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FOnKeyDown[Index];
end;

procedure TKeyData.SetKeyDown(Index: Integer; const Value: Boolean);
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	FKeyDown[Index] := Value;

	if Value and Assigned(FOnKeyDown[Index]) then FOnKeyDown[Index](Index);
end;

procedure TKeyData.SetOnKeyDown(Index: Integer; const Value: TSDLKeyEvent);
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	FOnKeyDown[Index] := Value;
end;

end.
