unit DTime;

interface

type
	TDClock = class
	protected
		LastTime: Int64;
	public
		constructor Create; virtual;
		function ExtractDT: Double; virtual;
		function ExtractIDT: Int64; virtual;
	end;

function GetTicks: Int64;

var
	SecsPerTick: Double;
	TicksPerSec: Int64;





implementation

uses
	LibC;

const
	CLOCK_MONOTONIC = 1;

{ TDClock }

constructor TDClock.Create;
begin
	LastTime := GetTicks;
end;

function TDClock.ExtractDT: Double;
begin
	Result := SecsPerTick * ExtractIDT;
end;

function TDClock.ExtractIDT: Int64;
var
	ThisTime: Int64;

begin
	ThisTime := GetTicks;
	Result := ThisTime - LastTime;
	LastTime := ThisTime;
end;





function GetTicks: Int64;
var
	TD: TTimeSpec;

begin
	clock_gettime(CLOCK_MONOTONIC, @TD);
	Result := TD.tv_sec;
	Result := Result * 1000000000 + TD.tv_nsec;
end;

procedure InitTimes;
var
	TD: TTimeSpec;

begin
	clock_getres(CLOCK_MONOTONIC, @TD);
	SecsPerTick := TD.tv_sec + TD.tv_nsec * 0.000000001;
	TicksPerSec := Round(1 / SecsPerTick);
end;

initialization
	InitTimes;
end.
