// Isolated diagnostic linker launcher. A private, never-switched desktop keeps
// SDK assertion dialogs off the user's desktop; a deadline terminates only this
// child. Diagnostics inspect only the owned child; no desktop capture is used.
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
public static class ContentLinkerHost {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {
    public int cb; public string reserved,desktop,title;
    public int x,y,xSize,ySize,xChars,yChars,fill,flags;
    public short show,reserved2; public IntPtr reservedPtr,input,output,error;
  }
  [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr process,thread; public int pid,tid; }
  [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateDesktop(string name,IntPtr device,IntPtr mode,int flags,uint access,IntPtr attributes);
  [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desktop);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string application,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,int flags,IntPtr environment,string directory,ref Startup startup,out ProcessInfo info);
  [DllImport("kernel32.dll")] static extern bool SetHandleInformation(IntPtr handle,int mask,int flags);
  [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
  [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
  [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle,uint code);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr process,IntPtr address,byte[] buffer,int size,out IntPtr read);
  [DllImport("kernel32.dll")] static extern uint SuspendThread(IntPtr thread);
  [DllImport("kernel32.dll")] static extern bool Wow64GetThreadContext(IntPtr thread,byte[] context);
  static byte[] Read(IntPtr process,int address,int count) {
    byte[] bytes=new byte[count]; IntPtr read;
    if(!ReadProcessMemory(process,new IntPtr(address),bytes,count,out read)) return new byte[count];
    return bytes;
  }
  static void Diagnostics(IntPtr process,IntPtr thread,string path) {
    int index=BitConverter.ToInt32(Read(process,0x118a54e4,4),0);
    uint position=BitConverter.ToUInt32(Read(process,0x118a54b8,4),0);
    int blocks=BitConverter.ToInt32(Read(process,0x118a54ac,4),0);
    byte[] data=Read(process,blocks,72),sizes=Read(process,0x5109f8,36);
    StringBuilder text=new StringBuilder(); text.AppendLine("Stream block diagnostics: index="+index+" position="+position);
    for(int i=0;i<9;i++) {
      uint start=BitConverter.ToUInt32(data,i*8),used=BitConverter.ToUInt32(data,i*8+4),limit=BitConverter.ToUInt32(sizes,i*4);
      text.AppendLine("block="+i+" start="+start+" used="+used+" limit="+limit+" currentOffset="+unchecked(position-start));
    }
    SuspendThread(thread);
    byte[] context=new byte[716]; Array.Copy(BitConverter.GetBytes(0x10007),context,4);
    if(Wow64GetThreadContext(thread,context)) {
      int frame=BitConverter.ToInt32(context,180);
      text.AppendLine("EIP="+BitConverter.ToUInt32(context,184).ToString("x"));
      for(int i=0;i<32 && frame>0;i++) {
        byte[] stack=Read(process,frame,8);
        text.AppendLine("return="+BitConverter.ToUInt32(stack,4).ToString("x"));
        int parent=BitConverter.ToInt32(stack,0); if(parent<=frame) break; frame=parent;
      }
    }
    File.WriteAllText(path+".memory.txt",text.ToString());
  }
  public static int Main(string[] args) {
    if(args.Length!=4) return 2;
    string desktopName="ApXContentBuild_"+Guid.NewGuid().ToString("N");
    IntPtr desktop=CreateDesktop(desktopName,IntPtr.Zero,IntPtr.Zero,0,0x01ff,IntPtr.Zero);
    if(desktop==IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
    ProcessInfo process=new ProcessInfo();
    try {
      using(FileStream log=new FileStream(args[2],FileMode.Create,FileAccess.Write,FileShare.ReadWrite)) {
        IntPtr handle=log.SafeFileHandle.DangerousGetHandle();
        if(!SetHandleInformation(handle,1,1)) throw new System.ComponentModel.Win32Exception();
        Startup startup=new Startup(); startup.cb=Marshal.SizeOf(startup); startup.desktop=desktopName;
        startup.flags=0x101; startup.show=0; startup.output=handle; startup.error=handle;
        string exe=Path.Combine(args[0],"bin","linker_pc.exe");
        StringBuilder command=new StringBuilder("\""+exe+"\" -language english -compress -cleanup -nopause "+args[1]);
        if(!CreateProcess(exe,command,IntPtr.Zero,IntPtr.Zero,true,0x08000000,IntPtr.Zero,Path.Combine(args[0],"bin"),ref startup,out process)) throw new System.ComponentModel.Win32Exception();
        uint result=WaitForSingleObject(process.process,uint.Parse(args[3]));
        if(result==258) { Diagnostics(process.process,process.thread,args[2]); TerminateProcess(process.process,124); WaitForSingleObject(process.process,5000); return 124; }
        uint code; GetExitCodeProcess(process.process,out code); return unchecked((int)code);
      }
    } finally {
      if(process.process!=IntPtr.Zero) CloseHandle(process.process);
      if(process.thread!=IntPtr.Zero) CloseHandle(process.thread);
      CloseDesktop(desktop);
    }
  }
}
