unit utils_async;

interface

uses
  Classes, SyncObjs
  {$IFDEF MSWINDOWS}
  , Windows
  {$ELSE}

  {$ENDIF}
  ;

type
  TASyncWorker = class;
  TOnASyncEvent = procedure(pvASyncWorker: TASyncWorker) of object;
  TASyncWorker = class(TThread)
  private
    FData: Pointer;
    FDataObj: TObject;
    FOnAsyncEvent: TOnASyncEvent;
    procedure SetDataObj(const Value: TObject);
  public
    constructor Create(AOnAsyncEvent: TOnASyncEvent);
    procedure Execute; override;
    property Data: Pointer read FData write FData;
    property DataObj: TObject read FDataObj write SetDataObj;

    property Terminated;     
  end;

  TASyncInvoker = class(TObject)
  private
    FOnAsyncEvent: TOnASyncEvent;
    FTerminated: Boolean;
    FStopEvent:TEvent;
    FWaitEvent: TEvent;
    FWorker:TASyncWorker;
    procedure InnerASync(pvWorker:TASyncWorker);
  public
    constructor Create;
    destructor Destroy; override;
    procedure WaitForSleep(pvTime:Cardinal);

    procedure Start(pvASyncEvent: TOnASyncEvent; pvData: Pointer = nil;
        pvDataObject: TObject = nil);
    procedure Terminate;
    procedure WaitForStop;

    property Terminated: Boolean read FTerminated write FTerminated;
  end;

function ASyncInvoke(pvASyncProc: TOnASyncEvent; pvData: Pointer = nil;
    pvDataObject: TObject = nil): TASyncWorker;

function CreateManualEvent(pvInitState: Boolean = false): TEvent;

function tick_diff(tick_start, tick_end: Cardinal): Cardinal;

function GetTickCount: Cardinal;

implementation

/// <summary>
///   计算两个TickCount时间差，避免超出49天后，溢出
///      感谢 [佛山]沧海一笑  7041779 提供
///      copy自 qsl代码
/// </summary>
function tick_diff(tick_start, tick_end: Cardinal): Cardinal;
begin
  if tick_end >= tick_start then
    result := tick_end - tick_start
  else
    result := High(Cardinal) - tick_start + tick_end;
end;

function ASyncInvoke(pvASyncProc: TOnASyncEvent; pvData: Pointer = nil;
    pvDataObject: TObject = nil): TASyncWorker;
begin
  Result := TASyncWorker.Create(pvASyncProc);
  Result.Data := pvData;
  Result.DataObj := pvDataObject;
  Result.Resume;
end;

function CreateManualEvent(pvInitState: Boolean = false): TEvent;
begin
  Result := TEvent.Create(nil, True, pvInitState, '');
end;

function GetTickCount: Cardinal;
begin
  {$IFDEF MSWINDOWS}
  Result := Windows.GetTickCount;
  {$ELSE}
  Result := TThread.GetTickCount;
  {$ENDIF}
end;

constructor TASyncWorker.Create(AOnAsyncEvent: TOnASyncEvent);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FOnAsyncEvent := AOnAsyncEvent;
end;

procedure TASyncWorker.Execute;
begin
  if Assigned(FOnAsyncEvent) then
  begin
    FOnAsyncEvent(Self);
  end;
end;

procedure TASyncWorker.SetDataObj(const Value: TObject);
begin
  FDataObj := Value;
end;

constructor TASyncInvoker.Create;
begin
  inherited Create;
  FStopEvent := TEvent.Create(nil, True, True, '');
  FWaitEvent := TEvent.Create(nil, True, true, '');
end;

destructor TASyncInvoker.Destroy;
begin
  FStopEvent.Free;
  FWaitEvent.Free;
  inherited;
end;

procedure TASyncInvoker.InnerASync(pvWorker:TASyncWorker);
begin
  FOnAsyncEvent(pvWorker);
  FStopEvent.SetEvent;
  FWorker := nil;
  FTerminated := True;
end;

procedure TASyncInvoker.Start(pvASyncEvent: TOnASyncEvent; pvData: Pointer =
    nil; pvDataObject: TObject = nil);
begin
  FTerminated := False;
  FStopEvent.ResetEvent;
  FOnAsyncEvent := pvASyncEvent;
  FWorker := ASyncInvoke(InnerASync, pvData, pvDataObject);
end;

procedure TASyncInvoker.Terminate;
begin
  if FWorker <> nil then FWorker.Terminate;
  FTerminated := True;
  FWaitEvent.SetEvent;
end;

procedure TASyncInvoker.WaitForSleep(pvTime:Cardinal);
begin
  FWaitEvent.ResetEvent;
  FWaitEvent.WaitFor(pvTime);
end;

procedure TASyncInvoker.WaitForStop;
begin
  FStopEvent.WaitFor(MaxInt);
end;

end.
