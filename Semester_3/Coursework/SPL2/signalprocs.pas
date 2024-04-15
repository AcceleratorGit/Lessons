unit SignalProcs;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, uComplex ;

const
  MaxSgnLen = 150000000;

type
  PRealArray = ^TRealArray;
  TRealArray = array[0..MaxSgnLen-1] of real;
  PComplexArray = ^TComplexArray;
  TComplexArray = array[0..MaxSgnLen-1] of complex;

  PfftRes = ^TfftRes;
  TfftRes = record
    ResSz: int64;
    ResPtr: PComplexArray;
   end;

  TfftResCollection = class(TObject)
    Count: integer;
    Ress: array[0..64] of TfftRes;
    constructor Create;
    destructor Destroy; override;
    function NewfftRes(aSz: int64): TfftRes;
    procedure DisposeLast;
  end;

  TfftCalc = class(TThread)
    SgnInP: PRealArray;
    SgnLen, StartPos, Step: int64;
    TermFlagP: ^wordbool;
    ThrCountP: ^word;
    XOutP: PComplexArray;
    constructor Create(var aSgnIn: TRealArray; aSgnLen, aStart, aStep: int64;
                       var anXOut: TComplexArray; var aTermFlag: wordbool;
                       var aThrCount: word);
    procedure Execute; override;
  end;

  TfftMixupThread = class(TThread)
    SgnLen, StartPos, Step: int64;
    Mult: complex;
    TermFlagP: ^wordbool;
    ThrCountP: ^word;
    XOutP: PComplexArray;
    constructor Create(aSgnLen, aStart, aStep: int64; aMult: complex;
                       var anXOut: TComplexArray; var aTermFlag: wordbool;
                       var aThrCount: word);
    procedure Execute; override;
  end;

  TThreadFunc = function(param: pointer): ptrint;

  PfftParam = ^TfftParam;
  TfftParam = record
    SgnInP: PRealArray;
    SgnLen, StartPos, Step: int64;
    Mult: complex;
    TermFlagP: ^wordbool;
    ThrCountP: ^LongWord;
    XOutP: PComplexArray;
  end;

  TBiSqrMatrix = record
    A1, A2, B0, B1, B2: double;
  end;

  TFltrMatrix = array[0..63] of TBiSqrMatrix;

  TDgtFltr = class(TObject)
    function FltrStep(new_x: double): double; virtual; abstract;
  end;

  TBiSqrFltr = class(TDgtFltr)
    A1, A2, B0, B1, B2: double;
    X_1, X_2, Y_1, Y_2: double;
    constructor Create(var Coeffs: TBiSqrMatrix);
    function FltrStep(new_x: double): double; override;
  end;

  TIIRFltr = class(TDgtFltr)
    BiSqrFltrs: array[0..63] of TBiSqrFltr;
    HalfOrd: word;
    constructor Create(var Coeffs: TFltrMatrix; aHO: word);
    function FltrStep(new_x: double): double; override;
    destructor Destroy; override;
  end;

  TBandPassFltr = class(TDgtFltr)
    LowFltr,HighFltr: TIIRFltr;
    constructor Create(var CoeffsLow, CoeffsHigh: TFltrMatrix; aHO: word);
    function FltrStep(new_x: double): double; override;
    destructor Destroy; override;
  end;

var
  RC: TfftResCollection;
  Xtemp: PComplexArray;
  Buff: array[0..63] of complex;

procedure fft1(var SgnIn: TRealArray; SgnLen, Start, Step: int64; var XOut: TComplexArray); cdecl;
procedure fft2(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; var XOut: TComplexArray); cdecl;

function fft(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64): TfftRes; cdecl;
function fftp(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; Depth: word): TfftRes; cdecl;

procedure fftcalc_thrd(var aSgnIn: TRealArray; aSgnLen, aStart, aStep: int64;
                       var anXOut: TComplexArray; var aTermFlag: wordbool;
                       var aThrCount: word);

function CreateBiSqrFilter(var Coeffs: TBiSqrMatrix): pointer; cdecl;
function FreeFilter(Fltr: pointer): wordbool; cdecl;
function FltrStep(Fltr: pointer; new_x: double): double; cdecl;

function FilterSignal(Fltr: pointer; var x: TRealArray; var y: TRealArray; SgnLen: int64): int64; cdecl;

function CreateIIRFilter(var Coeffs: TFltrMatrix; aHO: word): pointer; cdecl;

function CreateBandPassFilter(var CoeffsLow, CoeffsHigh: TFltrMatrix; aHO: word): pointer; cdecl;



implementation

// Функции, относящиеся  к цифровой фильтрации. Для внешнего вызова

function CreateBiSqrFilter(var Coeffs: TBiSqrMatrix): pointer; cdecl;
begin
  Result:=TBiSqrFltr.Create(Coeffs);
end;

function CreateIIRFilter(var Coeffs: TFltrMatrix; aHO: word): pointer; cdecl;
begin
  Result:=TIIRFltr.Create(Coeffs, aHO);
end;

function CreateBandPassFilter(var CoeffsLow, CoeffsHigh: TFltrMatrix; aHO: word): pointer; cdecl;
begin
  Result:=TBandPassFltr.Create(CoeffsLow, CoeffsHigh, aHO);
end;


function FreeFilter(Fltr: pointer): wordbool; cdecl;
begin
  try
    TDgtFltr(Fltr).Free;
    Result:=True;
  except
    Result:=False;
  end;
end;

function FltrStep(Fltr: pointer; new_x: double): double; cdecl;
begin
  try
    Result:=TDgtFltr(Fltr).FltrStep(new_x);
  except
    Result:=-1;
  end;
end;

function FilterSignal(Fltr: pointer; var x: TRealArray; var y: TRealArray; SgnLen: int64): int64; cdecl;
var
  N, ii: int64;
begin
  N:=0;
  for ii:=0 to SgnLen-1 do
  begin
    try
      y[ii]:=TDgtFltr(Fltr).FltrStep(x[ii]);
      //y[ii]:=10;
      inc(N);
    except
      Result:=N;
      exit;
    end;
  end;
  Result:=N;
end;

// Классы, реализующие цифровые фильтры

constructor TBiSqrFltr.Create(var Coeffs: TBiSqrMatrix);
begin
  inherited Create;
  A1:=Coeffs.A1;
  A2:=Coeffs.A2;
  B0:=Coeffs.B0;
  B1:=Coeffs.B1;
  B2:=Coeffs.B2;

  X_1:=0;
  X_2:=0;
  Y_1:=0;
  Y_2:=0;
end;

function TBiSqrFltr.FltrStep(new_x: double): double;
var
  Y: double;
begin
  Y:=X_2*B2+X_1*B1+new_x*B0-Y_2*A2-Y_1*A1;
  X_2:=X_1; X_1:=new_x;
  Y_2:=Y_1; Y_1:=Y;

  Result:=Y;

end;

constructor TIIRFltr.Create(var Coeffs: TFltrMatrix; aHO: word);
var
  jj: integer;
begin
  inherited Create;
  HalfOrd:=aHO;
  for jj:=0 to HalfOrd-1 do
    BiSqrFltrs[jj]:=TBiSqrFltr.Create(Coeffs[jj]);
end;

function TIIRFltr.FltrStep(new_x: double): double;
var
  jj: integer;
  new_y: double;
begin
  new_y:=BiSqrFltrs[0].FltrStep(new_x);
  for jj:=1 to HalfOrd-1 do
  begin
    new_y:=BiSqrFltrs[jj].FltrStep(new_y);
  end;
  Result:=new_y;
end;

destructor TIIRFltr.Destroy;
var
  jj: integer;
begin
  for jj:=0 to HalfOrd-1 do
    BiSqrFltrs[jj].Free;
  inherited;
end;


constructor TBandPassFltr.Create(var CoeffsLow, CoeffsHigh: TFltrMatrix; aHO: word);
begin
  inherited Create;
  LowFltr:=TIIRFltr.Create(CoeffsLow,aHO);
  HighFltr:=TIIRFltr.Create(CoeffsHigh,aHO);
end;

function TBandPassFltr.FltrStep(new_x: double): double;
var
  y1: double;
begin
  y1:=LowFltr.FltrStep(new_x);
  Result:=HighFltr.FltrStep(y1);
end;

destructor TBandPassFltr.Destroy;
begin
  LowFltr.Free;
  HighFltr.Free;
  inherited;
end;




// Процедуры, относящиеся к быстрому преобразованию Фурье

constructor TfftMixupThread.Create(aSgnLen, aStart, aStep: int64; aMult: complex;
                   var anXOut: TComplexArray; var aTermFlag: wordbool;
                   var aThrCount: word);
begin
  inherited Create(True);
  FreeOnTerminate:=True;
  SgnLen:=aSgnLen;
  StartPos:=aStart;
  Step:=aStep;
  Mult:=aMult;
  XOutP:=@anXOut;
  TermFlagP:=@aTermFlag;

  TermFlagP^:=False;

  ThrCountP:=@aThrCount;

  Priority:=tpHigher;

  Suspended:=False;

end;

procedure TfftMixupThread.Execute;
var
  k, Pos1: int64;
  X1,X2,eek: complex;
  XX: PComplexArray;
begin
  XX:=GetMem((SgnLen shl 1)*SizeOf(complex));
  Pos1:=StartPos;
  eek:=1;
  for k:=0 to SgnLen - 1 do
  begin
    X1:=XOutP^[Pos1]; X2:=XOutP^[Pos1+Step];
    XX^[k]:=X1+eek*X2;
    XX^[k+SgnLen]:=X1-eek*X2;

    Pos1:=Pos1 + Step shl 1;
    eek:=eek*Mult;
  end;
  Pos1:=StartPos;

  for k:=0 to (SgnLen shl 1 - 1) do
  begin
    XOutP^[Pos1]:=XX^[k];
    Pos1:=Pos1+Step;
  end;


  FreeMem(XX, (SgnLen shl 1)*SizeOf(complex));

  TermFlagP^:=True;
  if ThrCountP^>0 then dec(ThrCountP^);
end;

constructor TfftCalc.Create(var aSgnIn: TRealArray; aSgnLen, aStart, aStep: int64;
                            var anXOut: TComplexArray; var aTermFlag: wordbool;
                            var aThrCount: word);
begin
  inherited Create(True);
  FreeOnTerminate:=true;
  SgnInP:=@aSgnIn;
  SgnLen:=aSgnLen;
  StartPos:=aStart;
  Step:= aStep;
  XOutP:=@anXOut;
  TermFlagP:=@aTermFlag;
  TermFlagP^:=False;
  ThrCountP:=@aThrCount;

  Priority:=tpHigher;

  Suspended:=False;
end;

procedure TfftCalc.Execute;
begin
  fft2(SgnInP^,SgnLen,StartPos,Step,XOutP^);
  TermFlagP^:=True;
  if ThrCountP^>0 then dec(ThrCountP^);
end;

function Do_fftCalc(param: pointer): ptrint;
begin
  with PfftParam(param)^ do
  begin
      fft2(SgnInP^,SgnLen,StartPos,Step,XOutP^);
      TermFlagP^:=True;
      if ThrCountP^>0 then InterLockedDecrement(ThrCountP^);
  end;

  Dispose(PfftParam(param));
  Result:=0;
end;

function TestThrd (param: pointer): ptrint;
begin
  Dispose(PfftParam(param));
  Result:=0;
end;

procedure fftcalc_thrd (var aSgnIn: TRealArray; aSgnLen, aStart, aStep: int64;
                       var anXOut: TComplexArray; var aTermFlag: wordbool;
                       var aThrCount: word);
var
  fftparamP: PfftParam;
begin
  New(fftparamP);
  fftparamP^.SgnInP:=@aSgnIn;
  fftparamP^.SgnLen:=aSgnLen;
  fftparamP^.StartPos:=aStart;
  fftparamP^.Step:=aStep;
  fftparamP^.TermFlagP:=@aTermFlag;
  fftparamP^.ThrCountP:=@aThrCount;
  fftparamP^.XOutP:=@anXOut;

  BeginThread(@Do_fftCalc,pointer(fftparamP));
  //BeginThread(@TestThrd);

end;

constructor TfftResCollection.Create;
begin
  inherited Create;
  Count:=0;
end;

function TfftResCollection.NewfftRes(aSz: int64): TfftRes;
begin
  Ress[Count].ResSz:=aSz;
  Ress[Count].ResPtr:=GetMem(aSz);
  Result:=Ress[Count];
  inc(Count);
end;

procedure TfftResCollection.DisposeLast;
begin
  if Count>0 then
    begin
      dec(Count);
      FreeMem(Ress[Count].ResPtr,Ress[Count].ResSz);
    end;
end;

destructor TfftResCollection.Destroy;
begin
  while Count>0 do
    DisposeLast;
  inherited Destroy;
end;


procedure fft1(var SgnIn: TRealArray; SgnLen, Start, Step: int64; var XOut: TComplexArray); cdecl;
var
  //fr, fr1, fr2: TfftRes;
  HalfLen,k,Pos1,Pos2: int64;
  X1,X2,ee,eek: complex;
begin
  if SgnLen =  2
    then begin
           XOut[Start]:=SgnIn[Start]+SgnIn[Start+Step];
           XOut[Start+Step]:=SgnIn[Start]-SgnIn[Start+Step];
         end
    else begin
           HalfLen:=SgnLen shr 1;

           fft1(SgnIn,HalfLen,Start,Step shl 1,XOut);

           fft1(SgnIn,HalfLen,Start+Step,Step shl 1,XOut);

           ee:=cexp(-2*pi*i/SgnLen); eek:=1;
           Pos1:=Start; Pos2:=Start+Step;
           for k:=0 to HalfLen - 1 do
           begin
             X1:=XOut[Pos1]; X2:=XOut[Pos2];
             Xtemp^[k]:=X1+eek*X2;
             Xtemp^[k+HalfLen]:=X1-eek*X2;

             Pos1:=Pos1 + Step shl 1; Pos2:=Pos2 + Step shl 1;
             eek:=eek*ee;
           end;
           Pos1:=Start;
           for k:=0 to SgnLen - 1 do
           begin
             XOut[Pos1]:=Xtemp^[k];
             Pos1:=Pos1+Step;
           end;

         end;

end;

function Log2(NN: int64): integer;
var
  bt: int64;
  L2: integer;
begin
  bt:=1; L2:=0;
  while (bt and NN)<>bt do
  begin
    inc(L2);
    bt:=bt shl 1;
  end;
  Result:=L2;
end;

procedure fft2(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; var XOut: TComplexArray); cdecl;
var
  //fr, fr1, fr2: TfftRes;
  HalfLen, strt1, stp1, k, ii, GrCount, Pos1: int64;
  X1,X2,ee,eek: complex;
  XX: PComplexArray;
begin
  XX:=GetMem(SgnLen*SizeOf(Complex));
  strt1:=StartPos;
  GrCount:= SgnLen shr 1;   // = N/2
  stp1:=GrCount*Step;
  for ii:=0 to (GrCount - 1) do
  begin
    XOut[strt1]:=SgnIn[strt1]+SgnIn[strt1+stp1];
    XOut[strt1+stp1]:=SgnIn[strt1]-SgnIn[strt1+stp1];
    strt1:=strt1+Step;
  end;

  stp1:=stp1 shr 1;
  HalfLen:=2;
  GrCount:=GrCount shr 1;
  repeat
    ee:=cexp(-pi*i/HalfLen);
    strt1:=StartPos;
    for ii:=0 to GrCount-1 do
    begin
       eek:=1;
       Pos1:=strt1;
       for k:=0 to HalfLen - 1 do
       begin
         X1:=XOut[Pos1]; X2:=XOut[Pos1+stp1];
         XX^[k]:=X1+eek*X2;
         XX^[k+HalfLen]:=X1-eek*X2;

         Pos1:=Pos1 + stp1 shl 1;
         eek:=eek*ee;
       end;
       Pos1:=strt1;
       for k:=0 to HalfLen shl 1 - 1 do
       begin
         XOut[Pos1]:=XX^[k];
         Pos1:=Pos1+stp1;
       end;
       strt1:=strt1+Step;
    end;
    stp1:=stp1 shr 1;
    HalfLen:=HalfLen shl 1;
    GrCount:=GrCount shr 1;
  until stp1 < Step;
  FreeMem(XX,SgnLen*SizeOf(Complex));
end;

function fft(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64): TfftRes;  cdecl;
var
  fr: TfftRes;
begin
  fr:=RC.NewfftRes(SgnLen*SizeOf(Complex));
  fft2(SgnIn,SgnLen,StartPos,Step,fr.ResPtr^);
  Result:=fr;
end;




function fftp(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; Depth: word): TfftRes; cdecl;
// Depth - показатель глубины распараллеливания
// Если Depth=0, то всё вычисляется в одном потоке
var
  fr: TfftRes;
  tf: array[1..16] of wordbool;
  DepCount, Count, ThrCount, ic: word;
  strt: int64;
  ee: complex;
begin
  fr:=RC.NewfftRes(SgnLen*SizeOf(Complex));

  DepCount:=Depth;

  Count:=1 shl DepCount;
  strt:=StartPos;
  for ic:=1 to Count do
  begin
    //TfftCalc.Create(SgnIn,SgnLen shr DepCount,strt,Step shl DepCount,fr.ResPtr^,tf[ic],Count);
     fftcalc_thrd(SgnIn,SgnLen shr DepCount,strt,Step shl DepCount,fr.ResPtr^,tf[ic],Count);
    strt:=strt+Step;
  end;
  while Count>0 do;            // По-хорошему, нужен таймаут

// К этому месту вычислены БПФ с максимальным распараллеливанием
// Далее их перемешиваем с нужными множителями

  while DepCount>1 do
  begin
    Count:=1 shl (DepCount-1);
    ThrCount:=Count;
    strt:=StartPos;
    ee:=cexp(-(Count)*2*pi*i/SgnLen);
    for ic:=1 to Count do
    begin
      TfftMixupThread.Create(SgnLen shr (DepCount),strt,Step shl (DepCount-1),ee,fr.ResPtr^,tf[ic],ThrCount);
      strt:=strt+Step;
    end;
    while ThrCount>0 do;
    dec(DepCount);
  end;

  TfftMixupThread.Create(SgnLen shr 1,StartPos,Step,cexp(-2*pi*i/SgnLen),fr.ResPtr^,tf[1],ThrCount);
  while not (tf[1]) do;


  Result:=fr;
end;

initialization
  RC:=TfftResCollection.Create;


finalization
  RC.Free;

end.




