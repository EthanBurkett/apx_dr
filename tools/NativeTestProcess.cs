// Native server test lifetime on a private desktop. Never switches/captures the
// user's desktop; even game-created assertion dialogs stay on the owned desktop.
using System;
using System.Runtime.InteropServices;
using System.Text;
public sealed class ApXNativeTestProcess : IDisposable {
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {
        public int cb; public string reserved,desktop,title;
        public int x,y,width,height,xchars,ychars,fill,flags;
        public short show,reservedSize; public IntPtr reservedData,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] struct Info { public IntPtr process,thread; public int pid,tid; }
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateDesktop(string name,IntPtr device,IntPtr mode,int flags,uint access,IntPtr attributes);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string application,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,int flags,IntPtr environment,string directory,ref Startup startup,out Info info);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle,uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    IntPtr desktop,handle;
    public int Id { get; private set; }
    public bool HasExited { get { return WaitForSingleObject(handle,0)==0; } }
    public int ExitCode { get { uint code; if(!GetExitCodeProcess(handle,out code)) throw new System.ComponentModel.Win32Exception(); return unchecked((int)code); } }
    public ApXNativeTestProcess(string executable,string arguments,string directory) {
        string name="ApXNativeTest_"+Guid.NewGuid().ToString("N");
        desktop=CreateDesktop(name,IntPtr.Zero,IntPtr.Zero,0,0x1ff,IntPtr.Zero);
        if(desktop==IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
        Startup startup=new Startup(); startup.cb=Marshal.SizeOf(startup); startup.desktop=name; startup.flags=1;
        Info info;
        if(!CreateProcess(executable,new StringBuilder("\""+executable+"\" "+arguments),IntPtr.Zero,IntPtr.Zero,false,0x08000000,IntPtr.Zero,directory,ref startup,out info)) {
            int error=Marshal.GetLastWin32Error(); CloseDesktop(desktop); desktop=IntPtr.Zero;
            throw new System.ComponentModel.Win32Exception(error);
        }
        handle=info.process; Id=info.pid; CloseHandle(info.thread);
    }
    public void Kill() { if(handle!=IntPtr.Zero && !HasExited) TerminateProcess(handle,1); }
    public void WaitForExit() { if(WaitForSingleObject(handle,5000)==258) throw new TimeoutException("Owned native test did not terminate."); }
    public void Dispose() {
        if(handle!=IntPtr.Zero) { Kill(); WaitForExit(); CloseHandle(handle); handle=IntPtr.Zero; }
        if(desktop!=IntPtr.Zero) { CloseDesktop(desktop); desktop=IntPtr.Zero; }
    }
}
