unit SignalProcs;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, uComplex;

type
  PRealArray = ^TRealArray;
  TRealArray = array of real;
  PComplexArray = ^TComplexArray;
  TComplexArray = array[0..150000000] of complex;

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

var
  RC: TfftResCollection;
  Xtemp: PComplexArray;
  Buff: array[0..63] of complex;

procedure fft1(var SgnIn: TRealArray; SgnLen, Start, Step: int64; var XOut: TComplexArray); cdecl;
procedure fft2(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; var XOut: TComplexArray); cdecl;

function fft(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64): TfftRes; cdecl;
function fftp(var SgnIn: TRealArray; SgnLen, StartPos, Step: int64; Depth: word): TfftRes; cdecl;

implementation

constructor TfftMixupThread.Create(aSgnLen, aStart, aStep: int64; aMult: complex;
                   var anXOut: TComplexArray; var aTermFlag: wordbool;
                   var aThrCount: word);
begin
  inherited Create(True);
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
    TfftCalc.Create(SgnIn,SgnLen shr DepCount,strt,Step shl DepCount,fr.ResPtr^,tf[ic],Count);
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

  {fft2(SgnIn,SgnLen shr 1,StartPos,Step,fr.ResPtr^);
  fft2(SgnIn,SgnLen shr 1,StartPos+Step,Step,fr.ResPtr^);}

  Result:=fr;
end;
                                                                                              70
initialization
  RC:=TfftResCollection.Create;
  // Xtemp:=GetMem(64*SizeOf(complex));

finalization
 //  FreeMem(Xtemp,64*SizeOf(complex));
 RC.Free;

end.




