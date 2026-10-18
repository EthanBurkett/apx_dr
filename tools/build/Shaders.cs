using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

// Native Windows HLSL compiler; no downloaded executable or external SDK needed.
public static class ApXShaderCompiler
{
    [ComImport, Guid("8BA5FB08-5195-40e2-AC58-0D989C3A0102"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface Blob
    {
        [PreserveSig] IntPtr GetBufferPointer();
        [PreserveSig] UIntPtr GetBufferSize();
    }
    [DllImport("d3dcompiler_47.dll", CallingConvention=CallingConvention.StdCall)]
    private static extern int D3DCompile(byte[] source, UIntPtr size, [MarshalAs(UnmanagedType.LPStr)] string filename,
        IntPtr defines, IntPtr includes, [MarshalAs(UnmanagedType.LPStr)] string entry,
        [MarshalAs(UnmanagedType.LPStr)] string target, uint flags, uint effectFlags, out Blob code, out Blob errors);

    public static byte[] Compile(string path, string stage)
    {
        return Compile(path, stage, "3_0");
    }
    public static byte[] Compile(string path, string stage, string profile)
    {
        byte[] source = File.ReadAllBytes(path);
        Blob code = null, errors = null;
        try
        {
            int result = D3DCompile(source, (UIntPtr)source.Length, path, IntPtr.Zero, IntPtr.Zero,
                stage + "_main", stage + "_" + profile, 1u << 15, 0, out code, out errors);
            if (result < 0)
                throw new InvalidOperationException(errors == null ? "HLSL compile failed: " + result :
                    Marshal.PtrToStringAnsi(errors.GetBufferPointer(), (int)errors.GetBufferSize().ToUInt32()));
            int length = (int)code.GetBufferSize().ToUInt32();
            byte[] output = new byte[length + 4];
            Buffer.BlockCopy(BitConverter.GetBytes(length), 0, output, 0, 4);
            Marshal.Copy(code.GetBufferPointer(), output, 4, length);
            return output;
        }
        finally
        {
            if (code != null) Marshal.ReleaseComObject(code);
            if (errors != null) Marshal.ReleaseComObject(errors);
        }
    }

    public static uint NameHash(string name)
    {
        uint hash = 0;
        foreach (byte value in Encoding.ASCII.GetBytes(name)) hash = unchecked(hash * 33) ^ value;
        return hash;
    }
    public static uint BinaryHash(uint value)
    {
        return ~((value >> 24) | ((value >> 8) & 0xff00) | ((value << 8) & 0xff0000) | (value << 24));
    }
    public static byte[] Registry(byte[] baseline, string name)
    {
        var output = new MemoryStream();
        using (var reader = new BinaryReader(new MemoryStream(baseline)))
        using (var writer = new BinaryWriter(output))
        {
            for (int stage = 0; stage < 2; stage++)
            {
                uint count = reader.ReadUInt32();
                if (count > baseline.Length / 8) throw new InvalidDataException("Invalid SDK shader registry count");
                var entries = new SortedDictionary<uint,uint>();
                for (uint i = 0; i < count; i++) entries.Add(reader.ReadUInt32(), reader.ReadUInt32());
                uint hash = NameHash(name), binary = BinaryHash(hash);
                if (entries.ContainsKey(hash) && entries[hash] != binary)
                    throw new InvalidDataException("Custom shader name collides with SDK registry");
                entries[hash] = binary;
                writer.Write((uint)entries.Count);
                foreach (var pair in entries) { writer.Write(pair.Key); writer.Write(pair.Value); }
            }
            if (reader.BaseStream.Position != baseline.Length) throw new InvalidDataException("Trailing SDK shader registry data");
            writer.Flush();
            return output.ToArray();
        }
    }
}
