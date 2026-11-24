// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/binary"
	"fmt"
	"os"

	"golang.org/x/sys/windows"
)

func zcodeProviderFileIdentity(path string, info os.FileInfo) string {
	name, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return ""
	}
	handle, err := windows.CreateFile(name, windows.FILE_READ_ATTRIBUTES,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE, nil,
		windows.OPEN_EXISTING, windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return ""
	}
	defer windows.CloseHandle(handle)

	var stat windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &stat); err != nil ||
		stat.FileAttributes&(windows.FILE_ATTRIBUTE_REPARSE_POINT|windows.FILE_ATTRIBUTE_DIRECTORY) != 0 ||
		(stat.FileIndexHigh == 0 && stat.FileIndexLow == 0) ||
		(uint64(stat.FileSizeHigh)<<32|uint64(stat.FileSizeLow)) != uint64(info.Size()) ||
		stat.LastWriteTime.Nanoseconds() != info.ModTime().UnixNano() {
		return ""
	}
	// FILE_BASIC_INFO has four 64-bit timestamps. ChangeTime is the fourth.
	var basic [40]byte
	if err := windows.GetFileInformationByHandleEx(handle, windows.FileBasicInfo, &basic[0], uint32(len(basic))); err != nil {
		return ""
	}
	return fmt.Sprintf("%d:%d:%d:%d", stat.VolumeSerialNumber, stat.FileIndexHigh, stat.FileIndexLow,
		binary.LittleEndian.Uint64(basic[24:32]))
}
