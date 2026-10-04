// Copyright (c) 2026 Benj Weaver. MIT; see LICENSE.
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <roapi.h>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <vector>
#include <memory>
#include "PowerToysModule.h"
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "runtimeobject.lib")
namespace fs = std::filesystem;
constexpr UINT TRAY = WM_APP + 1, INVOKE = WM_APP + 2;
constexpr UINT EXIT = 1, CONFIG = 2, RELOAD = 3, EDITOR = 4, TOGGLE = 5;
struct Module { HMODULE library{}; PowertoyModuleIface* api{}; std::wstring path; };
struct Shortcut { size_t module, index; WORD mods, key; bool extended; };
std::vector<Module> modules;
std::vector<Shortcut> shortcuts;
std::wstring utility, ini, configFolder;
fs::path root;
HWND window{}; HHOOK hook{};
NOTIFYICONDATAW tray{};
bool enabled = false;
bool down[256]{}, swallowed[256]{};
bool Invoke(size_t i);
void SuppressMenu() {
 INPUT input{};input.type=INPUT_KEYBOARD;input.ki.wVk=0xFF;input.ki.dwFlags=KEYEVENTF_KEYUP;
 input.ki.dwExtraInfo=PowertoyModuleIface::CENTRALIZED_KEYBOARD_HOOK_DONT_TRIGGER_FLAG;SendInput(1,&input,sizeof(input));
}
std::wstring Setting(const wchar_t* key) {
 wchar_t text[32768]{}; GetPrivateProfileStringW(L"App", key, L"", text, 32768, ini.c_str()); return text;
}
void Log(const std::wstring& text) {
 std::wofstream file(root / L"host.log", std::ios::app); file << GetTickCount64() << L" " << text << L"\n";
}
WORD Modifiers() {
 WORD mods=0;
 if (GetAsyncKeyState(VK_MENU)&0x8000) mods|=MOD_ALT;
 if (GetAsyncKeyState(VK_CONTROL)&0x8000) mods|=MOD_CONTROL;
 if (GetAsyncKeyState(VK_SHIFT)&0x8000) mods|=MOD_SHIFT;
 if ((GetAsyncKeyState(VK_LWIN)|GetAsyncKeyState(VK_RWIN))&0x8000) mods|=MOD_WIN;
 return mods;
}
LRESULT CALLBACK Keyboard(int code, WPARAM msg, LPARAM param) {
 if(code>=0) {
  auto key=reinterpret_cast<KBDLLHOOKSTRUCT*>(param);
  if(key->vkCode<256 && key->dwExtraInfo!=PowertoyModuleIface::CENTRALIZED_KEYBOARD_HOOK_DONT_TRIGGER_FLAG) {
   bool pressed=msg==WM_KEYDOWN || msg==WM_SYSKEYDOWN;
   bool released=msg==WM_KEYUP || msg==WM_SYSKEYUP;
   bool repeat=down[key->vkCode];
   if(pressed) down[key->vkCode]=true;
   if(enabled && (pressed || released)) {
    bool win=key->vkCode==VK_LWIN || key->vkCode==VK_RWIN;
    for(size_t m=0;m<modules.size();++m) {
     if(pressed && !repeat && win && modules[m].api->keep_track_of_pressed_win_key()) SetTimer(window,1000+m,modules[m].api->milliseconds_win_key_must_be_pressed(),nullptr);
     else if(released || (pressed && !win)) KillTimer(window,1000+m);
    }
   }
   if(released) {
    down[key->vkCode]=false;
    if(swallowed[key->vkCode]){swallowed[key->vkCode]=false;return 1;}
   }
   if(pressed && repeat && swallowed[key->vkCode])return 1;
   if(pressed && !repeat && enabled) {
    auto mods=Modifiers();
    for(size_t i=0;i<shortcuts.size();++i) {
     auto& s=shortcuts[i];
     if(s.key==key->vkCode && s.mods==mods) {
      // Preserve the upstream on_hotkey return contract. Peek, for example,
      // declines activation outside Explorer, so that input must pass through.
      if(Invoke(i)) { swallowed[key->vkCode]=true;SuppressMenu();return 1; }
     }
    }
   }
  }
 }
 return CallNextHookEx(hook,code,msg,param);
}
void UpdateShortcuts() {
 shortcuts.clear();
 for(size_t m=0;m<modules.size();++m) {
  auto api=modules[m].api;
  auto count=api->get_hotkeys(nullptr,0);
  if(count>256) throw std::runtime_error("Invalid hotkey count");
  std::vector<PowertoyModuleIface::Hotkey> keys(count); api->get_hotkeys(keys.data(),count);
  for(size_t k=0;k<count;++k) {
   auto h=keys[k]; if(!h.key || !h.isShown) continue;
   WORD mods= (h.win?MOD_WIN:0)|(h.ctrl?MOD_CONTROL:0)|(h.shift?MOD_SHIFT:0)|(h.alt?MOD_ALT:0);
   shortcuts.push_back({m,k,mods,h.key,false});
  }
  auto extended=api->GetHotkeyEx();
  if(extended && extended->vkCode) shortcuts.push_back({m,0,extended->modifiersMask,extended->vkCode,true});
 }
}
bool Invoke(size_t i) {
 if(i>=shortcuts.size() || !enabled) return false;
 auto s=shortcuts[i];
 bool handled=true;
 if(s.extended) modules[s.module].api->OnHotkeyEx();
 else handled=modules[s.module].api->on_hotkey(s.index);
 Log(L"Invoked shortcut "+std::to_wstring(i)+(handled?L"; handled":L"; passed through"));
 return handled;
}
std::wstring ShortcutLabel(const Shortcut& s) {
 std::wstring text;
 if(s.mods&MOD_WIN) text+=L"Win+";
 if(s.mods&MOD_CONTROL) text+=L"Ctrl+";
 if(s.mods&MOD_ALT) text+=L"Alt+";
 if(s.mods&MOD_SHIFT) text+=L"Shift+";
 wchar_t name[128]{}; UINT scan=MapVirtualKeyW(s.key,MAPVK_VK_TO_VSC);
 GetKeyNameTextW(scan<<16,name,128);
 text+=*name?name:std::to_wstring(s.key); return text;
}
void Reload() {
 for(auto& m: modules) {
  fs::path file=fs::path(configFolder)/m.api->get_key()/L"settings.json";
  if(fs::exists(file)) {
   // Native settings files are UTF-8. Preserve their complete JSON contract.
   std::ifstream in(file,std::ios::binary); std::string bytes((std::istreambuf_iterator<char>(in)),{});
   if(bytes.starts_with("\xef\xbb\xbf")) bytes.erase(0,3);
   int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,bytes.data(),static_cast<int>(bytes.size()),nullptr,0);
   if(!count) throw std::runtime_error("Invalid settings UTF-8");
   std::wstring text(count,L'\0'); MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,bytes.data(),static_cast<int>(bytes.size()),text.data(),count);
   m.api->set_config(text.c_str());
  }
 }
 UpdateShortcuts(); Log(L"Settings reloaded");
}
void SetEnabled(bool value) {
 for(auto& m:modules) {
  if(value) { if(m.api->gpo_policy_enabled_configuration()==powertoys_gpo::gpo_rule_configured_disabled) throw std::runtime_error("Utility disabled by Windows policy"); m.api->enable(); }
  else m.api->disable();
 }
 enabled=value; UpdateShortcuts();
 std::wstring tip=utility+(value?L" — On":L" — Off"); wcsncpy_s(tray.szTip,tip.c_str(),_TRUNCATE);
 Shell_NotifyIconW(NIM_MODIFY,&tray); Log(value?L"Enabled":L"Disabled");
}
void Menu() {
 auto menu=CreatePopupMenu();
 AppendMenuW(menu,MF_STRING|MF_DISABLED,0,utility.c_str());
 AppendMenuW(menu,MF_STRING|(enabled?MF_CHECKED:0),TOGGLE,L"Enabled");
 for(size_t i=0;i<shortcuts.size();++i) AppendMenuW(menu,MF_STRING|(enabled?0:MF_GRAYED),100+static_cast<UINT>(i),(L"Activate: "+ShortcutLabel(shortcuts[i])).c_str());
 if(!Setting(L"Editor").empty() || !Setting(L"EditorEvent").empty()) AppendMenuW(menu,MF_STRING,EDITOR,L"Open editor");
 AppendMenuW(menu,MF_STRING,CONFIG,L"Open settings folder");
 AppendMenuW(menu,MF_STRING,RELOAD,L"Reload settings");
 AppendMenuW(menu,MF_SEPARATOR,0,nullptr); AppendMenuW(menu,MF_STRING,EXIT,L"Exit");
 POINT p; GetCursorPos(&p); SetForegroundWindow(window);
 auto command=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_RIGHTBUTTON,p.x,p.y,0,window,nullptr); DestroyMenu(menu);
 if(command) PostMessageW(window,WM_COMMAND,command,0);
 PostMessageW(window,WM_NULL,0,0);
}
LRESULT CALLBACK WindowProc(HWND w,UINT msg,WPARAM wp,LPARAM lp) {
 try {
  if(msg==RegisterWindowMessageW(L"TaskbarCreated")) { Shell_NotifyIconW(NIM_ADD,&tray); return 0; }
  if(msg==TRAY && (lp==WM_RBUTTONUP || lp==WM_LBUTTONUP)) { Menu(); return 0; }
  if(msg==INVOKE) { Invoke(wp); return 0; }
  if(msg==WM_TIMER && wp>=1000 && wp<1000+modules.size()) {
   auto module=wp-1000;KillTimer(w,wp);
   if(enabled && modules[module].api->keep_track_of_pressed_win_key()) { modules[module].api->on_hotkey(static_cast<size_t>(-1));SuppressMenu(); }
   return 0;
  }
  if(msg==WM_COMMAND) {
   if(wp==EXIT) DestroyWindow(w);
   else if(wp==TOGGLE) SetEnabled(!enabled);
   else if(wp==RELOAD) Reload();
   else if(wp==CONFIG) { auto path=fs::path(configFolder)/modules.front().api->get_key(); fs::create_directories(path); ShellExecuteW(w,L"open",path.c_str(),nullptr,nullptr,SW_SHOWNORMAL); }
   else if(wp==EDITOR && !Setting(L"EditorEvent").empty()) { auto event=OpenEventW(EVENT_MODIFY_STATE,FALSE,Setting(L"EditorEvent").c_str()); if(event){SetEvent(event);CloseHandle(event);} }
   else if(wp==EDITOR) { auto editor=(root/Setting(L"Editor")); ShellExecuteW(w,L"open",editor.c_str(),Setting(L"EditorArgs").c_str(),editor.parent_path().c_str(),SW_SHOWNORMAL); }
   else if(wp>=100) Invoke(wp-100);
   return 0;
  }
  if(msg==WM_DESTROY) { PostQuitMessage(0); return 0; }
 } catch(const std::exception& e) { MessageBoxA(w,e.what(),"PowerToys Individual",MB_ICONERROR); }
 return DefWindowProcW(w,msg,wp,lp);
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR args,int) {
 root=fs::path([]{wchar_t p[32768]{};GetModuleFileNameW(nullptr,p,32768);return std::wstring(p);}()).parent_path();
 SetCurrentDirectoryW(root.c_str()); ini=(root/L"app.ini").wstring(); utility=Setting(L"Name");
 if(utility.empty()) return 2;
 int count=0; auto argv=CommandLineToArgvW(GetCommandLineW(),&count);
 std::wstring mode=count==2?argv[1]:L""; if(argv)LocalFree(argv);
 const bool smoke=mode==L"--smoke";
 Log(L"Starting; args="+std::wstring(args));
 std::wstring mutexName=L"Local\\PowerToysIndividual-"+utility;
 HANDLE mutex=CreateMutexW(nullptr,TRUE,mutexName.c_str());
 if(GetLastError()==ERROR_ALREADY_EXISTS) { if(mode==L"--quit") { auto old=FindWindowW(L"PowerToysIndividualHost",utility.c_str()); if(old)PostMessageW(old,WM_CLOSE,0,0); } CloseHandle(mutex); return 0; }
 if(mode==L"--quit") { CloseHandle(mutex); return 0; }
 RoInitialize(RO_INIT_SINGLETHREADED);
 wchar_t appdata[MAX_PATH]{}; SHGetFolderPathW(nullptr,CSIDL_LOCAL_APPDATA,nullptr,0,appdata); configFolder=(fs::path(appdata)/L"Microsoft"/L"PowerToys").wstring();
 WNDCLASSW wc{};wc.lpfnWndProc=WindowProc;wc.hInstance=instance;wc.lpszClassName=L"PowerToysIndividualHost";RegisterClassW(&wc);
 window=CreateWindowW(wc.lpszClassName,utility.c_str(),0,0,0,0,0,nullptr,nullptr,instance,nullptr);
 tray.cbSize=sizeof(tray);tray.hWnd=window;tray.uID=1;tray.uFlags=NIF_ICON|NIF_MESSAGE|NIF_TIP;tray.uCallbackMessage=TRAY;tray.hIcon=ExtractIconW(instance,(root/Setting(L"Icon")).c_str(),0);if(!tray.hIcon || tray.hIcon==reinterpret_cast<HICON>(1))tray.hIcon=LoadIconW(nullptr,IDI_APPLICATION);wcsncpy_s(tray.szTip,utility.c_str(),_TRUNCATE);Shell_NotifyIconW(NIM_ADD,&tray);
 int result=0;
 try {
  if(fs::exists(root/L"WinUI3Apps")) SetDllDirectoryW((root/L"WinUI3Apps").c_str());
  for(int i=0;i<16;++i) {
   auto name=Setting((L"Module"+std::to_wstring(i)).c_str());if(name.empty())break;
   auto library=LoadLibraryW((root/name).c_str());
   if(!library) throw std::runtime_error("Cannot load utility DLL; Windows error "+std::to_string(GetLastError()));
   auto create=reinterpret_cast<powertoy_create_func>(GetProcAddress(library,"powertoy_create"));
   if(!create) throw std::runtime_error("Utility does not export powertoy_create");
   auto api=create();if(!api)throw std::runtime_error("Utility factory returned null");modules.push_back({library,api,name});
  }
  if(modules.empty()) throw std::runtime_error("No utility module configured");
  SetEnabled(true);
  hook=SetWindowsHookExW(WH_KEYBOARD_LL,Keyboard,instance,0);
  if(!hook)throw std::runtime_error("Cannot install keyboard hook");
  Log(L"Ready; hotkeys="+std::to_wstring(shortcuts.size()));
  // Noninteractive automated test invokes the same dispatch as real hotkeys/tray.
  if(smoke) { Log(L"Smoke dispatch"); if(!shortcuts.empty()) Invoke(0); else if(!Setting(L"Editor").empty()) SendMessageW(window,WM_COMMAND,EDITOR,0); SetTimer(window,1,5000,[](HWND w,UINT,UINT_PTR,DWORD){DestroyWindow(w);}); }
  MSG message{};while(GetMessageW(&message,nullptr,0,0)>0){TranslateMessage(&message);DispatchMessageW(&message);}
 } catch(const std::exception& e) { Log(L"Failed; "+std::wstring(e.what(),e.what()+strlen(e.what()))); if(!smoke)MessageBoxA(nullptr,e.what(),"PowerToys Individual",MB_ICONERROR);result=1; }
 if(hook)UnhookWindowsHookEx(hook);
 for(auto it=modules.rbegin();it!=modules.rend();++it){it->api->disable();it->api->destroy(); /* Keep DLL mapped until all native worker threads terminate. */}
 Shell_NotifyIconW(NIM_DELETE,&tray);Log(L"Stopped");RoUninitialize();CloseHandle(mutex);return result;
}
