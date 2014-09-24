{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     �й����Լ��Ŀ���Դ�������������                         }
{                   (C)Copyright 2001-2014 CnPack ������                       }
{                   ------------------------------------                       }
{                                                                              }
{            ���������ǿ�Դ���������������������� CnPack �ķ���Э������        }
{        �ĺ����·�����һ����                                                }
{                                                                              }
{            ������һ��������Ŀ����ϣ�������ã���û���κε���������û��        }
{        �ʺ��ض�Ŀ�Ķ������ĵ���������ϸ���������� CnPack ����Э�顣        }
{                                                                              }
{            ��Ӧ���Ѿ��Ϳ�����һ���յ�һ�� CnPack ����Э��ĸ��������        }
{        ��û�У��ɷ������ǵ���վ��                                            }
{                                                                              }
{            ��վ��ַ��http://www.cnpack.org                                   }
{            �����ʼ���master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnSM3;
{* |<PRE>
================================================================================
* �������ƣ�������������
* ��Ԫ���ƣ�����ɢ���㷨SM3��Ԫ
* ��Ԫ���ߣ���Х��liuxiao@cnpack.org)
* ��    ע���ο������㷨�����ĵ���SM3 Cryptographic Hash Algorith��
*           http://www.oscca.gov.cn/UpFile/20101222141857786.pdf
*           ���ο���ֲgoldboar��C����
* ����ƽ̨��Windows 7 + Delphi 5.0
* ���ݲ��ԣ�PWin9X/2000/XP/7 + Delphi 5/6
* �� �� �����õ�Ԫ�е��ַ��������ϱ��ػ�������ʽ
* ��Ԫ��ʶ��$Id$
* �޸ļ�¼��2014.09.23 V1.0
*               ��ֲ��������Ԫ
================================================================================
|</PRE>}

interface

{$I CnPack.inc}

uses
  Windows, Classes, SysUtils;

type
  TSM3Context = packed record
    Total: array[0..1] of DWORD;     {!< number of bytes processed  }
    State: array[0..8] of DWORD;     {!< intermediate digest state  }
    Buffer: array[0..63] of Byte;    {!< data block being processed }
    Ipad: array[0..63] of Byte;      {!< HMAC: inner padding        }
    Opad: array[0..63] of Byte;      {!< HMAC: outer padding        }
  end;
  PSM3Context = ^TSM3Context;

  TSM3Digest = array[0..31] of Byte;

  TSM3CalcProgressFunc = procedure (ATotal, AProgress: Int64;
    var Cancel: Boolean) of object;

procedure SM3Start(var Ctx: TSM3Context);

procedure SM3Update(var Ctx: TSM3Context; Input: PAnsiChar; Length: LongWord);

procedure SM3Finish(var Ctx: TSM3Context; var Output: TSM3Digest);

procedure SM3(Input: PAnsiChar; Length: LongWord; var Output: TSM3Digest);
{* �����ݿ����SM3����
 |<PRE>
   Input: PAnsiChar  - Ҫ��������ݿ�
   Length: LongWord  - ���ݿ鳤��
 |</PRE>}

procedure SM3HmacStarts(var Ctx: TSM3Context; Key: PAnsiChar; KeyLength: Integer);

procedure SM3HmacUpdate(var Ctx: TSM3Context; Input: PAnsiChar; Length: LongWord);

procedure SM3HmacFinish(var Ctx: TSM3Context; var Output: TSM3Digest);

procedure SM3Hmac(Key: PAnsiChar; KeyLength: Integer; Input: PAnsiChar;
  Length: LongWord; var Output: TSM3Digest);

function SM3String(const Str: string): TSM3Digest;
{* ��String�������ݽ���SM3ת����ע��D2009�����ϰ汾��stringΪUnicodeString��
   ��˶�ͬһ���ַ����ļ���������D2007�����°汾�Ļ᲻ͬ��ʹ��ʱ��ע��
 |<PRE>
   Str: string       - Ҫ������ַ���
 |</PRE>}

function SM3StringA(const Str: AnsiString): TSM3Digest;
{* ��AnsiString�������ݽ���SM3ת��
 |<PRE>
   Str: AnsiString       - Ҫ������ַ���
 |</PRE>}

function SM3StringW(const Str: WideString): TSM3Digest;
{* �� WideString�������ݽ���SM3ת��
 |<PRE>
   Str: WideString       - Ҫ������ַ���
 |</PRE>}

function SM3File(const FileName: string;
  CallBack: TSM3CalcProgressFunc = nil): TSM3Digest;
{* ��ָ���ļ����ݽ���SM3����
 |<PRE>
   FileName: string  - Ҫ������ļ���
   CallBack: TSM3PgressFunc - ���Ȼص�������Ĭ��Ϊ��
 |</PRE>}

function SM3Print(const Digest: TSM3Digest): string;
{* ��ʮ�����Ƹ�ʽ���SM3����ֵ
 |<PRE>
   Digest: TSM3Digest  - ָ����SM3����ֵ
 |</PRE>}
 
implementation

const
  SM3Padding: array[0..63] of Byte =
    (
      $80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    );

type
  TSM3ProcessData = array[0..63] of Byte;

procedure GetULongBe(var N: DWORD; B: PAnsiChar; I: Integer);
var
  D: DWORD;
begin
  D := (DWORD(B[I]) shl 24) or (DWORD(B[I + 1]) shl 16) or
    (DWORD(B[I + 2]) shl 8) or (DWORD(B[I + 3]));
  N := D;
end;

procedure PutULongBe(N: DWORD; B: PAnsiChar; I: Integer);
begin
  B[I] := AnsiChar(N shr 24);
  B[I + 1] := AnsiChar(N shr 16);
  B[I + 2] := AnsiChar(N shr 8);
  B[I + 3] := AnsiChar(N);
end;

function FF0(X, Y, Z: DWORD): DWORD;
begin
  Result := X xor Y xor Z;
end;

function FF1(X, Y, Z: DWORD): DWORD;
begin
  Result := (X and Y) or (Y and Z) or (X and Z);
end;

function GG0(X, Y, Z: DWORD): DWORD;
begin
  Result := X xor Y xor Z;
end;

function GG1(X, Y, Z: DWORD): DWORD;
begin
  Result := (X and Y) or ((not X) and Z);
end;

function SM3Shl(X: DWORD; N: Integer): DWORD;
begin
  Result := (X and $FFFFFFFF) shl N;
end;

function ROTL(X: DWORD; N: Integer): DWORD;
begin
  Result := SM3Shl(X, N) or (X shr (32 - N));
end;

function P0(X: DWORD): DWORD;
begin
  Result := X xor ROTL(X, 9) xor ROTL(X, 17);
end;

function P1(X: DWORD): DWORD;
begin
  Result := X xor ROTL(X, 15) xor ROTL(X, 23);
end;

procedure SM3Start(var Ctx: TSM3Context);
begin
  Ctx.Total[0] := 0;
  Ctx.Total[1] := 0;

  Ctx.State[0] := $7380166F;
  Ctx.State[1] := $4914B2B9;
  Ctx.State[2] := $172442D7;
  Ctx.State[3] := $DA8A0600;
  Ctx.State[4] := $A96F30BC;
  Ctx.State[5] := $163138AA;
  Ctx.State[6] := $E38DEE4D;
  Ctx.State[7] := $B0FB0E4E;

  ZeroMemory(@Ctx.Buffer, SizeOf(Ctx.Buffer));
  ZeroMemory(@Ctx.Ipad, SizeOf(Ctx.Ipad));
  ZeroMemory(@Ctx.Opad, SizeOf(Ctx.Opad));
end;

// һ�δ��� 64byte Ҳ����512bit ���ݿ�
procedure SM3Process(var Ctx: TSM3Context; Data: PAnsiChar);
var
  SS1, SS2, TT1, TT2: DWORD;
  W: array[0..67] of DWORD;
  W1: array[0..63] of DWORD;
  T: array[0..63] of DWORD;
  A, B, C, D, E, F, G, H: DWORD;
  Temp1, Temp2, Temp3, Temp4, Temp5: DWORD;
  J: Integer;
begin
  for J := 0 to 15 do
    T[J] := $79CC4519;
  for J := 16 to 63 do
    T[J] := $7A879D8A;

  GetULongBe(W[ 0], Data,  0);
  GetULongBe(W[ 1], Data,  4);
  GetULongBe(W[ 2], Data,  8);
  GetULongBe(W[ 3], Data, 12);
  GetULongBe(W[ 4], Data, 16);
  GetULongBe(W[ 5], Data, 20);
  GetULongBe(W[ 6], Data, 24);
  GetULongBe(W[ 7], Data, 28);
  GetULongBe(W[ 8], Data, 32);
  GetULongBe(W[ 9], Data, 36);
  GetULongBe(W[10], Data, 40);
  GetULongBe(W[11], Data, 44);
  GetULongBe(W[12], Data, 48);
  GetULongBe(W[13], Data, 52);
  GetULongBe(W[14], Data, 56);
  GetULongBe(W[15], Data, 60);

  for J := 16 to 67 do
  begin
    Temp1 := W[J - 16] xor W[J - 9];
    Temp2 := ROTL(W[J - 3], 15);
    Temp3 := Temp1 xor Temp2;
    Temp4 := P1(Temp3);
    Temp5 := ROTL(W[J - 13],7 ) xor W[J - 6];
    W[J] := Temp4 xor Temp5;
  end;

  for J := 0 to 63 do
    W1[J] := W[J] xor W[J + 4];

  // �Ѿ�������������W/W1��ֵ��
  
  A := Ctx.State[0];
  B := Ctx.State[1];
  C := Ctx.State[2];
  D := Ctx.State[3];
  E := Ctx.State[4];
  F := Ctx.State[5];
  G := Ctx.State[6];
  H := Ctx.State[7];

  for J := 0 to 15 do
  begin
    SS1 := ROTL((ROTL(A, 12) + E + ROTL(T[J], J)), 7);
    SS2 := SS1 xor ROTL(A, 12);
    TT1 := FF0(A, B, C) + D + SS2 + W1[J];
    TT2 := GG0(E, F, G) + H + SS1 + W[J];
    D := C;
    C := ROTL(B, 9);
    B := A;
    A := TT1;
    H := G;
    G := ROTL(F, 19);
    F := E;
    E := P0(TT2);
  end;

  for J := 16 to 63 do
  begin
    SS1 := ROTL((ROTL(A, 12) + E + ROTL(T[J], J)), 7);
    SS2 := SS1 xor ROTL(A, 12);
    TT1 := FF1(A, B, C) + D + SS2 + W1[J];
    TT2 := GG1(E, F, G) + H + SS1 + W[J];
    D := C;
    C := ROTL(B,9);
    B := A;
    A := TT1;
    H := G;
    G := ROTL(F,19);
    F := E;
    E := P0(TT2);
  end;

  Ctx.State[0] := Ctx.State[0] xor A;
  Ctx.State[1] := Ctx.State[1] xor B;
  Ctx.State[2] := Ctx.State[2] xor C;
  Ctx.State[3] := Ctx.State[3] xor D;
  Ctx.State[4] := Ctx.State[4] xor E;
  Ctx.State[5] := Ctx.State[5] xor F;
  Ctx.State[6] := Ctx.State[6] xor G;
  Ctx.State[7] := Ctx.State[7] xor H;

  // ��������
end;

procedure SM3UpdateW(var Context: TSM3Context; Input: PWideChar; Length: LongWord);
var
  pContent: PAnsiChar;
  iLen: Cardinal;
begin
  GetMem(pContent, Length * SizeOf(WideChar));
  try
    iLen := WideCharToMultiByte(0, 0, Input, Length, // ����ҳĬ���� 0
      PAnsiChar(pContent), Length * SizeOf(WideChar), nil, nil);
    SM3Update(Context, pContent, iLen);
  finally
    FreeMem(pContent);
  end;
end;


procedure SM3Update(var Ctx: TSM3Context; Input: PAnsiChar; Length: LongWord);
var
  Fill: Integer;
  Left: DWORD;
begin
  if Length <= 0 then
    Exit;

  Left := Ctx.Total[0] and $3F;
  Fill := 64 - Left;

  Ctx.Total[0] := Ctx.Total[0] + Length;
  Ctx.Total[0] := Ctx.Total[0] and $FFFFFFFF;

  if Ctx.Total[0] < DWORD(Length) then
    Ctx.Total[1] := Ctx.Total[1] + 1;

  if (Left <> 0) and (Length >= Fill) then
  begin
    CopyMemory(@(Ctx.Buffer[Left]), Input, Fill);
    SM3Process(Ctx, @(Ctx.Buffer[0]));
    Input := Input + Fill;
    Length := Length - Fill;
    Left := 0;
  end;

  while Length >= 64 do
  begin
    SM3Process(Ctx, Input);
    Input := Input + 64;
    Length := Length - 64;
  end;

  if Length > 0 then
    CopyMemory(@(Ctx.Buffer[Left]), Input, Length);
end;

procedure SM3Finish(var Ctx: TSM3Context; var Output: TSM3Digest);
var
  Last, Padn: DWORD;
  High, Low: DWORD;
  MsgLen: array[0..7] of Byte;
begin
  High := (Ctx.Total[0] shr 29) or (Ctx.Total[1] shl 3);
  Low := Ctx.Total[0] shl 3;

  PutULongBe(High, @(MsgLen[0]), 0);
  PutULongBe(Low, @(MsgLen[0]), 4);

  Last := Ctx.Total[0] and $3F;
  if Last < 56 then
    Padn := 56 - Last
  else
    Padn := 120 - Last;

  SM3Update(Ctx, @(SM3Padding[0]), Padn);
  SM3Update(Ctx, @(MsgLen[0]), 8);

  PutULongBe( Ctx.State[0], @Output,  0 );
  PutULongBe( Ctx.State[1], @Output,  4 );
  PutULongBe( Ctx.State[2], @Output,  8 );
  PutULongBe( Ctx.State[3], @Output, 12 );
  PutULongBe( Ctx.State[4], @Output, 16 );
  PutULongBe( Ctx.State[5], @Output, 20 );
  PutULongBe( Ctx.State[6], @Output, 24 );
  PutULongBe( Ctx.State[7], @Output, 28 );
end;

procedure SM3(Input: PAnsiChar; Length: LongWord; var Output: TSM3Digest);
var
  Ctx: TSM3Context;
begin
  SM3Start(Ctx);
  SM3Update(Ctx, Input, Length);
  SM3Finish(Ctx, Output);
end;

procedure SM3HmacStarts(var Ctx: TSM3Context; Key: PAnsiChar; KeyLength: Integer);
var
  I: Integer;
  Sum: TSM3Digest;
begin
  if KeyLength > 64 then
  begin
    SM3(Key, KeyLength, Sum);
    KeyLength := 32;
    Key := @(Sum[0]);
  end;

  FillChar(Ctx.Ipad, $36, 64);
  FillChar(Ctx.Opad, $5C, 64);

  for I := 0 to KeyLength - 1 do
  begin
    Ctx.Ipad[I] := Byte(Ctx.Ipad[I] xor Byte(Key[I]));
    Ctx.Opad[I] := Byte(Ctx.Opad[I] xor Byte(Key[I]));
  end;

  SM3Start(Ctx);
  SM3Update(Ctx, @(Ctx.Ipad[0]), 64);
end;

procedure SM3HmacUpdate(var Ctx: TSM3Context; Input: PAnsiChar; Length: LongWord);
begin
  SM3Update(Ctx, Input, Length);
end;

procedure SM3HmacFinish(var Ctx: TSM3Context; var Output: TSM3Digest);
var
  Len: Integer;
  TmpBuf: TSM3Digest;
begin
  Len := 32;
  SM3Finish(Ctx, TmpBuf);
  SM3Start(Ctx);
  SM3Update(Ctx, @(Ctx.Opad[0]), 64);
  SM3Update(Ctx, @(TmpBuf[0]), Len);
  SM3Finish(Ctx, Output);
end;

procedure SM3Hmac(Key: PAnsiChar; KeyLength: Integer; Input: PAnsiChar;
  Length: LongWord; var Output: TSM3Digest);
var
  Ctx: TSM3Context;
begin
  SM3HmacStarts(Ctx, Key, KeyLength);
  SM3HmacUpdate(Ctx, Input, Length);
  SM3HmacFinish(Ctx, Output);
end;

// ��String�������ݽ���SM3ת��
function SM3String(const Str: string): TSM3Digest;
var
  AStr: AnsiString;
begin
  AStr := AnsiString(Str);
  Result := SM3StringA(AStr);
end;

// ��AnsiString�������ݽ���SM3ת��
function SM3StringA(const Str: AnsiString): TSM3Digest;
var
  Context: TSM3Context;
begin
  SM3Start(Context);
  SM3Update(Context, PAnsiChar(Str), Length(Str));
  SM3Finish(Context, Result);
end;

// ��WideString�������ݽ���SM3ת��
function SM3StringW(const Str: WideString): TSM3Digest;
var
  Context: TSM3Context;
begin
  SM3Start(Context);
  SM3UpdateW(Context, PWideChar(Str), Length(Str));
  SM3Finish(Context, Result);
end;

function InternalSM3Stream(Stream: TStream; const BufSize: Cardinal; var D:
  TSM3Digest; CallBack: TSM3CalcProgressFunc = nil): Boolean;
var
  Context: TSM3Context;
  Buf: PAnsiChar;
  BufLen: Cardinal;
  Size: Int64;
  ReadBytes: Cardinal;
  TotalBytes: Int64;
  SavePos: Int64;
  CancelCalc: Boolean;
begin
  Result := False;
  Size := Stream.Size;
  SavePos := Stream.Position;
  TotalBytes := 0;
  if Size = 0 then Exit;
  if Size < BufSize then BufLen := Size
  else BufLen := BufSize;

  CancelCalc := False;
  SM3Start(Context);
  GetMem(Buf, BufLen);
  try
    Stream.Seek(0, soFromBeginning);
    repeat
      ReadBytes := Stream.Read(Buf^, BufLen);
      if ReadBytes <> 0 then
      begin
        Inc(TotalBytes, ReadBytes);
        SM3Update(Context, Buf, ReadBytes);
        if Assigned(CallBack) then
        begin
          CallBack(Size, TotalBytes, CancelCalc);
          if CancelCalc then Exit;
        end;
      end;
    until (ReadBytes = 0) or (TotalBytes = Size);
    SM3Finish(Context, D);
    Result := True;
  finally
    FreeMem(Buf, BufLen);
    Stream.Position := SavePos;
  end;
end;

// ��ָ���ļ����ݽ���SM3ת��
function SM3File(const FileName: string;
  CallBack: TSM3CalcProgressFunc): TSM3Digest;
var
  FileHandle: THandle;
  MapHandle: THandle;
  ViewPointer: Pointer;
  Context: TSM3Context;
  Stream: TStream;

  function FileSizeIsLargeThan2G(const AFileName: string): Boolean;
  var
    H: THandle;
    Info: BY_HANDLE_FILE_INFORMATION;
    Rec : Int64Rec;
  begin
    Result := False;
    H := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
    if H = INVALID_HANDLE_VALUE then Exit;
    try
      if not GetFileInformationByHandle(H, Info) then Exit;
    finally
      CloseHandle(H);
    end;
    Rec.Lo := Info.nFileSizeLow;
    Rec.Hi := Info.nFileSizeHigh;
    Result := (Rec.Hi > 0) or (Rec.Lo > Cardinal(MaxInt));
  end;

begin
  if FileSizeIsLargeThan2G(FileName) then
  begin
    // ���� 2G ���ļ����� Map ʧ�ܣ���������ʽѭ������
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      InternalSM3Stream(Stream, 4096 * 1024, Result, CallBack);
    finally
      Stream.Free;
    end;
  end
  else
  begin
    SM3Start(Context);
    FileHandle := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ or
                  FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL or
                  FILE_FLAG_SEQUENTIAL_SCAN, 0);
    if FileHandle <> INVALID_HANDLE_VALUE then
    begin
      try
        MapHandle := CreateFileMapping(FileHandle, nil, PAGE_READONLY, 0, 0, nil);
        if MapHandle <> 0 then
        begin
          try
            ViewPointer := MapViewOfFile(MapHandle, FILE_MAP_READ, 0, 0, 0);
            if ViewPointer <> nil then
            begin
              try
                SM3Update(Context, ViewPointer, GetFileSize(FileHandle, nil));
              finally
                UnmapViewOfFile(ViewPointer);
              end;
            end
            else
            begin
              raise Exception.Create('MapViewOfFile Failed.');
            end;
          finally
            CloseHandle(MapHandle);
          end;
        end
        else
        begin
          raise Exception.Create('CreateFileMapping Failed.');
        end;
      finally
        CloseHandle(FileHandle);
      end;
    end;
    SM3Finish(Context, Result);
  end;
end;

function SM3Print(const Digest: TSM3Digest): string;
var
  I: Integer;
const
  Digits: array[0..15] of AnsiChar = ('0', '1', '2', '3', '4', '5', '6', '7',
                                  '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
begin
  Result := '';
  for I := 0 to 31 do
    Result := Result + {$IFDEF DELPHI12_UP}string{$ENDIF}(Digits[(Digest[I] shr 4) and $0f] +
              Digits[Digest[I] and $0F]);
end;

end.