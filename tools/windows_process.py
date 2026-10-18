"""Owned native test process on a private, never-switched Windows desktop.

CREATE_NO_WINDOW alone cannot suppress GUI-subsystem crash/message boxes.
This wrapper isolates those dialogs without inspecting the user's desktop.
"""
import ctypes
from ctypes import wintypes as w
import subprocess
import uuid


class Startup(ctypes.Structure):
    _fields_=[('cb',w.DWORD),('reserved',w.LPWSTR),('desktop',w.LPWSTR),('title',w.LPWSTR),
              ('x',w.DWORD),('y',w.DWORD),('width',w.DWORD),('height',w.DWORD),
              ('xchars',w.DWORD),('ychars',w.DWORD),('fill',w.DWORD),('flags',w.DWORD),
              ('show',w.WORD),('reserved_size',w.WORD),('reserved_data',ctypes.c_void_p),
              ('input',w.HANDLE),('output',w.HANDLE),('error',w.HANDLE)]


class ProcessInfo(ctypes.Structure):
    _fields_=[('process',w.HANDLE),('thread',w.HANDLE),('pid',w.DWORD),('tid',w.DWORD)]


class IsolatedProcess:
    def __init__(self,args,cwd):
        self.kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        self.user=ctypes.WinDLL('user32',use_last_error=True)
        self.user.CreateDesktopW.argtypes=[w.LPCWSTR,ctypes.c_void_p,ctypes.c_void_p,w.DWORD,w.DWORD,ctypes.c_void_p]
        self.user.CreateDesktopW.restype=w.HANDLE
        self.user.CloseDesktop.argtypes=[w.HANDLE]
        self.kernel.CreateProcessW.argtypes=[w.LPCWSTR,w.LPWSTR,ctypes.c_void_p,ctypes.c_void_p,w.BOOL,w.DWORD,
                                            ctypes.c_void_p,w.LPCWSTR,ctypes.POINTER(Startup),ctypes.POINTER(ProcessInfo)]
        self.kernel.CreateProcessW.restype=w.BOOL
        self.kernel.WaitForSingleObject.argtypes=[w.HANDLE,w.DWORD]
        self.kernel.GetExitCodeProcess.argtypes=[w.HANDLE,ctypes.POINTER(w.DWORD)]
        self.kernel.TerminateProcess.argtypes=[w.HANDLE,w.UINT]
        self.kernel.CloseHandle.argtypes=[w.HANDLE]
        name='ApXAssetAudit_'+uuid.uuid4().hex
        self.desktop=self.user.CreateDesktopW(name,None,None,0,0x1ff,None)
        if not self.desktop:raise ctypes.WinError(ctypes.get_last_error())
        startup=Startup();startup.cb=ctypes.sizeof(startup);startup.desktop=name
        startup.flags=1;startup.show=0
        info=ProcessInfo();command=ctypes.create_unicode_buffer(subprocess.list2cmdline(args))
        if not self.kernel.CreateProcessW(args[0],command,None,None,False,0x08000000,None,str(cwd),ctypes.byref(startup),ctypes.byref(info)):
            self.user.CloseDesktop(self.desktop)
            raise ctypes.WinError(ctypes.get_last_error())
        self.kernel.CloseHandle(info.thread)
        self.handle=info.process;self.pid=info.pid;self.returncode=None

    def poll(self):
        if self.returncode is None and self.kernel.WaitForSingleObject(self.handle,0)==0:
            code=w.DWORD()
            if not self.kernel.GetExitCodeProcess(self.handle,ctypes.byref(code)):raise ctypes.WinError(ctypes.get_last_error())
            self.returncode=ctypes.c_int(code.value).value
        return self.returncode

    def terminate(self):
        if self.poll() is None:self.kernel.TerminateProcess(self.handle,1)

    kill=terminate

    def wait(self,timeout=5):
        if self.kernel.WaitForSingleObject(self.handle,int(timeout*1000))==258:
            raise subprocess.TimeoutExpired('isolated native test',timeout)
        return self.poll()

    def close(self):
        self.kernel.CloseHandle(self.handle)
        self.user.CloseDesktop(self.desktop)
