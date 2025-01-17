#include "slick.sh"
#include "tagsdb.sh"
#import "tagwin.e"

#include "xretrace.sh"

#pragma option(strictsemicolons,on)
//#pragma option(strict,on)
//#pragma option(autodecl,off)
#pragma option(strictparens,on)


#if __VERSION__ < 25
#undef bool
#define bool boolean
#endif

#undef XUN
#undef XUNS

#define XUN(a) user_graeme_##a
#define XUNS "user_graeme_"


#include "DLinkList.esh"
#include "xtemp-file-manager.esh"
#include "xblock-selection-editor.esh"


static bool    xxutils_debug = false;


static void xxdebug(...)
{
   if ( !xxutils_debug ) 
      return;
   _str s1 = "xr: ";
   int k = 0;
   while ( ++k <= arg()) {
      s1 = s1 :+ arg(k) :+ ' ';
   }
   // https://www.epochconverter.com/
   say(_time('G') :+ s1);
}


_command void XUN(toggle_xxutils_debug)()
{
   if ( xxutils_debug ) {
      xxdebug("xxutils debug off");
      xxutils_debug = false;
   }
   else
   {
      xxutils_debug = true;
      xxdebug("xxutils debug on");
      say("Use F1 for help, Ctrl K to clear");
   }
}



static int diff_region1_start_line;
static int diff_region1_end_line;
static bool diff_region1_set;
static _str diff_region1_filename;
static bool diff_region1_auto_length;
   
_command void run_typora() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   if (_no_child_windows()) {
      _message_box("No buffer is open");
      return;
   }
   if (_isno_name(p_DocumentName) || p_buf_name == '') {
      _message_box("No buffer is open");
      return;
   }
   save();
   shell("typora " p_buf_name, "QA");
}

_command void XUN(xset_diff_region)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   if (_isno_name(p_DocumentName) || p_buf_name == '') {
      _message_box("Save the file before using this command");
      diff_region1_set = false;
      return;
   }

   if (select_active2()) {
      typeless p1;
      save_pos(p1);
      _begin_select();
      diff_region1_start_line = p_line;
      _end_select();
      diff_region1_end_line = p_line;
      restore_pos(p1);
      diff_region1_auto_length = false;
   }
   else
   {
      diff_region1_start_line = p_line;
      diff_region1_end_line = p_line + 50;
      diff_region1_auto_length = true;
   }
   diff_region1_filename = p_buf_name;
   diff_region1_set = true;
}
   
   
_command void XUN(xcompare_diff_region)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   if (_isno_name(p_DocumentName) || p_buf_name == '') {
      _message_box("Save the file before using this command");
      return;
   }

   if (diff_region1_set) {
      int diff_region2_start_line;
      int diff_region2_end_line;
      if (select_active2()) {
         typeless p1;
         save_pos(p1);
         _begin_select();
         diff_region2_start_line = p_line;
         if (diff_region1_auto_length && (diff_region1_filename == p_buf_name) 
                                                  && (diff_region1_start_line < p_line)) {
            if (diff_region1_end_line >= p_line) {
               diff_region1_end_line = p_line - 1;
            }
         }
         _end_select();
         diff_region2_end_line = p_line;
         restore_pos(p1);
      }
      else
      {
         diff_region2_start_line = p_line;
         if (diff_region1_auto_length && (diff_region1_filename == p_buf_name)
                                                  && (diff_region1_start_line < p_line)) {
            if (diff_region1_end_line >= p_line) {
               diff_region1_end_line = p_line - 1;
            }
         }
         diff_region2_end_line = p_line + (diff_region1_end_line - diff_region1_start_line) + 20;
      }

      _DiffModal('-range1:' :+ diff_region1_start_line ',' :+ diff_region1_end_line :+ 
                 ' -range2:' :+ diff_region2_start_line ',' :+ diff_region2_end_line :+ ' ' :+ 
                 _maybe_quote_filename(diff_region1_filename) ' '  _maybe_quote_filename(p_buf_name));
   }
}
   

_command void XUN(xbeautify_project)(bool ask = true, bool no_preview = false, bool autosave = true) name_info(',')
{
   _str files_to_beautify [];

   //_GetWorkspaceFiles(_workspace_filename, files_to_beautify);
   _getProjectFiles( _workspace_filename, _project_get_filename(), files_to_beautify, 1);

   if (ask && !no_preview) {
      activate_preview();
   }

   int k;
   for (k = 0; k < files_to_beautify._length(); ++k) {
      if (ask) {

         if (!no_preview) {
            struct VS_TAG_BROWSE_INFO cm;
            tag_browse_info_init(cm);
            cm.member_name = files_to_beautify[k];
            cm.file_name = files_to_beautify[k];
            cm.line_no = 1;
            cb_refresh_output_tab(cm, true, false, false);
            _UpdateTagWindowDelayed(cm, 0);
         }

         _str res = _message_box("Beautify " :+ files_to_beautify[k], "Beautify project", MB_YESNOCANCEL|IDYESTOALL);
         if (res == IDCANCEL) return;
         if (res == IDNO) continue;
         if (res == IDYESTOALL) ask = false;
      }

      if (edit("+B " :+ files_to_beautify[k]) == 0) {
         beautify();
         if (autosave) save();
      }
      else
      {
         edit(files_to_beautify[k]);
         beautify();
         if (autosave) save();
         quit();
      }
   }
}


static _str get_search_cur_word()
{
   int start_col = 0;
   word := "";
   if (select_active2()) {
      if (!_begin_select_compare()&&!_end_select_compare()) {
         /* get text out of selection */
         last_col := 0;
         buf_id   := 0;
         _get_selinfo(start_col,last_col,buf_id);
         if (_select_type('','I')) ++last_col;
         if (_select_type()=='LINE') {
            get_line(auto line);
            word=line;
            start_col=0;
         } else {
            word=_expand_tabsc(start_col,last_col-start_col);
         }
         _deselect();
      }else{
         deselect();
         word=cur_word(start_col,'',1);
      }
   }else{
      word=cur_word(start_col,'',1);
   }
   return word;
}


_command int XUN(xsearch_workspace_cur_word_now)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   _str sw = get_search_cur_word();
   if (sw != '') {
      _str ss = _get_active_grep_view();
      _str grep_id = '0';
      if (ss != '') {
         parse ss with "_search" grep_id; 
      }
      return _mffind2(sw,'I','<Workspace>','*.*','','32',grep_id);
      //return _mffind2(sw,'I','<Workspace>','*.*','','32',auto_increment_grep_buffer());
   }
   return 0;
}


_command int XUN(xsearch_workspace_whole_cur_word_now)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   _str sw = get_search_cur_word();
   if (sw != '') {
      _str ss = _get_active_grep_view();
      _str grep_id = '0';
      if (ss != '') {
         parse ss with "_search" grep_id; 
      }
      //return _mffind2(sw,'IW','<Workspace>','*.*','','32',grep_id);
      return _mffind2(sw,'IW','<Workspace>','*.*','','32',auto_increment_grep_buffer());
   }
   return 0;
}


_command int XUN(xsearch_cur_word)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   _str sw = get_search_cur_word();
   if (sw == '') 
      return 0;

   int formid;
   if (isEclipsePlugin()) {
      show('-xy _tbfind_form');
      formid = _find_object('_tbfind_form._findstring');
      if (formid) {
         formid._set_focus();
      }
   } else {
      #if __VERSION__  >=  25
      tool_gui_find();  
      #else
      gui_find();
      #endif
      formid = activate_tool_window('_tbfind_form', true, '_findstring');
   }

   if (!formid) {
      return 0;
   }
   _control _findstring;
   formid._findstring.p_text = sw;
   formid._findstring._set_sel(1,length(sw)+1);
   return 1;
}


_command void XUN(xupcase_char)()name_info(',' VSARG2_REQUIRES_EDITORCTL)
{
   _select_char();
   cursor_right();
   _select_char();
   upcase_selection();
}


_command void XUN(xlowcase_char)()name_info(',' VSARG2_REQUIRES_EDITORCTL)
{
   _select_char();
   cursor_right();
   _select_char();
   lowcase_selection();
}


// copy path plus filename of the current buffer to the clipboard
_command void XUN(xcurbuf_path_to_clip)() name_info(','VSARG2_MACRO|VSARG2_READ_ONLY)
{
   _str str;
   if (_no_child_windows()) {
      return;
   }
   else { 
      str = _mdi.p_child.p_buf_name;
   }
   push_clipboard_itype('CHAR','',1,true);
   append_clipboard_text(str);
}

// copy name (excluding path) of the current buffer to the clipboard
_command void XUN(xcurbuf_name_to_clip)() name_info(','VSARG2_MACRO|VSARG2_READ_ONLY)
{
   if (_no_child_windows()) {
      return;
   }
   push_clipboard_itype('CHAR','',1,true);
   append_clipboard_text(strip_filename(_mdi.p_child.p_buf_name,'P'));
}

_command void XUN(xproject_name_to_clip)() name_info(',')
{
   push_clipboard_itype('CHAR','',1,true);
   append_clipboard_text(_project_name);
}


// explore configuration folder
_command void XUN(explore_config)() name_info(',')
{
   explore(_config_path());
}


static _str get_vsroot_dir()
{
   _str root_dir = get_env('VSROOT');
   _maybe_append_filesep(root_dir);
   return root_dir;
}

// explore slickedit installation folder
_command void XUN(explore_vslick)() name_info(',')
{
   explore(get_vsroot_dir());
}


// explore slickedit installation docs folder
_command void XUN(explore_docs)() name_info(',')
{
   explore(get_vsroot_dir() :+ 'docs');
}

// explore active project vpj folder
_command void XUN(explore_vpj)() name_info(',')
{
   explore(_project_name);
}


// explore current buffer or pathname (if supplied as first parameter)
_command void XUN(explore_cur_buffer)() name_info(',')
{
   if (arg()) {
      if (file_exists(arg(1))) {
         explore(arg(1));
         return;
      } 
   }
   if (_no_child_windows()) {
      return;
   }

   if (file_exists(_mdi.p_child.p_buf_name)) {
      explore( _mdi.p_child.p_buf_name );
   }
}


static _str get_open_path(...)
{
   if (arg()) {
      if (file_exists(arg(1))) {
         return arg(1);
      } 
   }
   if (_no_child_windows()) {
      return strip_filename(_project_get_filename(),'N');
   }
   else if (file_exists(_mdi.p_child.p_buf_name)) {
      return strip_filename(_mdi.p_child.p_buf_name,'N');
   } else {
      return strip_filename(_project_get_filename(),'N');
   }
}

// open from path of current buffer or from specified path (if supplied as
// the first parameter
_command void XUN(xopen_from_here)() name_info(',')
{
   chdir(get_open_path(arg(1)),1);
   gui_open();
}

// open from configuration folder
_command void XUN(xopen_from_config)() name_info(',')
{
   chdir(_config_path(),1);
   gui_open();
}


// open vsstack error file
_command void XUN(xopvss)() name_info(',')
{
   edit(strip_filename(GetErrorFilename(),'N') :+ 'vsstack');
}


_command void XUN(xopen_logs)() name_info(',')
{
   edit(_config_path() :+ "logs" :+ FILESEP :+ "vs.log");
   edit(_config_path() :+ "logs" :+ FILESEP :+ "pip.log");
   edit(_config_path() :+ "logs" :+ FILESEP :+ "stack.log");
}

//============================================================================================
// notepad
//============================================================================================


static int notepad_number = 0;
static int get_notepad_number()
{
   if ( ++notepad_number > 99 ) {
      notepad_number = 1;
   }
   return notepad_number;
}

#if __VERSION__ < 25
const MAX_WIDTH_IN_PIXELS = 800;
const  INITIAL_HEIGHT   = 4000;
const  INITIAL_WIDTH  = 3000;
#else
static const MAX_WIDTH_IN_PIXELS = 800;
static const  INITIAL_HEIGHT   = 4000;
static const  INITIAL_WIDTH  = 3000;
#endif

static typeless def_notepad_font = '';


static int pix2scale(int pix,int wid)
{
   return _dx2lx(wid.p_xyscale_mode, pix);
}

static int scale2pix(int scale,int wid)
{
   return _lx2dx(wid.p_xyscale_mode, scale);
}



static _str get_the_longest_line() 
{
   int loops = 100000;
   int maxl = 0;
   int ll = 0;
   top();
   while (--loops) {
      end_line();
      if (p_col > maxl) {
         ll = p_line;
         maxl = p_col;
      }
      if (down())
         break;
   }
   goto_line(ll);
   get_line(ss);
   return ss;
}


_command void XUN(xnotepad_word)() name_info(',')
{
   XUN(xnotepad)(true);
}

_command void XUN(xnotepad_create_time_date_string)() name_info(',')
{
   XUN(xnotepad)(false, stranslate(_date('I'),'-','/') :+ '-' :+ stranslate(_time('M'), '-', ':'));  
}



/* places selected text in a floating 'notepad' window.  If a notepad window
   already exists, current selection is appended.
*/
_command void XUN(xnotepad)(bool select_word = false, _str string1 = '') name_info(','MARK_ARG2|VSARG2_MULTI_CURSOR|VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY)
{
   typeless p;
   save_pos(p);
   int pwin = p_window_id;
   bool no_selection = false;

   if ( !select_active() ) {
      no_selection = true;
      if (select_word) 
         select_whole_word();
      else
         select_line();
   }

   if (select_active()) {
      _str select_type = _select_type();
      typeless oldsel = _duplicate_selection();
      wid = _find_object('notepadform','n');
      if (!wid) {

         _mdi.p_child._GetVisibleScreen(auto screen_x, auto screen_y, auto screen_width, auto screen_height);
         int screen_midpt_x = (screen_width intdiv 2);
         int screen_midpt_y = (screen_height intdiv 2);

         wid = _create_window(OI_FORM,
                              _mdi,
                              'Notepad ' :+ get_notepad_number(),
                              _dx2lx(SM_TWIP, screen_midpt_x - 300),   // create window needs twips
                              _dy2ly(SM_TWIP, screen_midpt_y - 300),
                              INITIAL_WIDTH,//width
                              INITIAL_HEIGHT, //height
                              CW_PARENT,
                              BDS_SIZABLE);

         wid.p_name = 'notepadform';

         if (wid) {
            editorwid = _create_window(OI_EDITOR,
                                       wid,
                                       '', // Title
                                       - _twips_per_pixel_x(), // x - yep, this is negative
                                       - _twips_per_pixel_y(), // y
                                       wid.p_width - _twips_per_pixel_x(),
                                       wid.p_height - _twips_per_pixel_y(),
                                       CW_CHILD);
            int wid2 = p_window_id;
            p_window_id = editorwid;
            p_auto_size = 0;
            p_multi_select = MS_EDIT_WINDOW;
            p_scroll_bars = SB_BOTH;
            p_width = (wid.p_client_width + 2) * _twips_per_pixel_x();
            p_height = (wid.p_client_height + 2) * _twips_per_pixel_y();
            p_name = 'editwin';
            if (def_notepad_font != '') {
               parse def_notepad_font with fname','fsize;
               p_font_name = fname;
               if (fsize != '') {
                  p_font_size = fsize;
               }
            }
            else
            {
               def_notepad_font = p_font_name :+ ',' :+ p_font_size;
            }
            editorwid.top();
            editorwid.delete_line();

            if ( select_type != 'LINE' ) 
               editorwid.insert_line('');

            p_window_id = wid2;
            index = find_index('user_graeme_notepad_resize', EVENTTAB_TYPE);
            if (index) {
               wid.p_eventtab = index;
            }
         }
      }
      else {
         _control editwin;
         editorwid = wid.editwin;
         if ( select_type == 'LINE' ) {
            editorwid.bottom();
            editorwid.up();
            editorwid.end_line();
         }
         else
         {
            editorwid.bottom();
            editorwid.begin_line();
         }
      }
      _mdi._set_focus();

      if ( string1 != '' ) {
         editorwid.insert_line(string1);
      }
      else
      {
         editorwid._copy_to_cursor();
         if (select_type == 'CHAR' || select_type == 'BLOCK') {
            editorwid.insert_line('');
         }
      }
      _str ss = editorwid.get_the_longest_line();
      editorwid.bottom();
      editorwid.begin_line();
      int ww = editorwid._text_width(ss) + pix2scale(50, editorwid);
      editorwid.get_line(ss);
      if ( ss != '' ) {
         editorwid.end_line();
         editorwid.insert_line('');
      }
      if ( ww > pix2scale(MAX_WIDTH_IN_PIXELS, editorwid) ) {
         ww = pix2scale(MAX_WIDTH_IN_PIXELS, editorwid);
      }
      if ( ww > wid.p_width ) {
         wid.p_width = ww;
         editorwid.p_width = wid.p_width; 
      }
      _deselect();
      _mdi.p_child._set_focus();
      activate_window(pwin);
      restore_pos(p);
      if ( !no_selection ) 
         _show_selection(oldsel);
   }
}

defeventtab user_graeme_notepad_resize;

user_graeme_notepad_resize.on_resize()
{
   int x = _control editwin;
   int wid = p_window_id;
   p_window_id = x;
   p_width = (wid.p_client_width + 2) * _twips_per_pixel_x();
   p_height = (wid.p_client_height + 2) * _twips_per_pixel_y();
   p_window_id = wid;
}


//============================================================================================
// key bindings stuff
//============================================================================================



static _str get_key_binding_name(_str keyname)
{
   int index = event2index(name2event(keyname));
   index = eventtab_index(_default_keys, _default_keys, index);
   if (index)
      return translate(name_name(index),'_','-');
   return '';
}


static output_key_binding(_str keyname, bool use_double = false)
{
   _str s = get_key_binding_name(keyname);
   if (s != '')  {
      if (use_double) {
         // use double quotes if the keyname contains a single quote
         _str k = substr(keyname :+ '"= ',1,16);
         insert_line('  "' :+ k :+ s :+ ';');
      }
      else {
         _str k = substr(keyname :+ "\'= ",1,16);
         insert_line("  \'" :+ k :+ s :+ ';');
      }
   }
}


static output_key_family(_str base_key)
{
   bool use_double = base_key == "'";
   output_key_binding(base_key, use_double);
   output_key_binding('S-' :+ base_key, use_double);
   output_key_binding('C-' :+ base_key, use_double);
   output_key_binding('A-' :+ base_key, use_double);
   output_key_binding('C-S-' :+ base_key, use_double);
   output_key_binding('A-S-' :+ base_key, use_double);
   output_key_binding('C-A-' :+ base_key, use_double);
   output_key_binding('C-A-S-' :+ base_key, use_double);
   insert_line('');
}


_command void XUN(xxkey_bindings_show)() name_info(','VSARG2_TEXT_BOX|VSARG2_REQUIRES_EDITORCTL|VSARG2_LINEHEX)
{
   _str fn = _ConfigPath() :+ 'keybindings' FILESEP 'group-keydefs.e';
   if ( !isdirectory(_ConfigPath() :+ 'keybindings') ) {
      mkdir(_ConfigPath() :+ 'keybindings');
   }
   if ( !file_exists(fn) ) {
      if (edit(' +t ' _maybe_quote_filename(fn))) {
         return;
      }
   }
   else
   {
      if (edit(_maybe_quote_filename(fn))) {
         return;
      }
   }
   if (p_buf_name != fn) {
      return;
   }
   delete_all();

   insert_line('');
   insert_line('');

   insert_line('  // ********************  FUNCTION KEYS  ********************');
   insert_line('');

   int k;
   for (k =1; k < 13; ++k) {
      output_key_family('F' :+ k);
   }

   insert_line('  // ********************  NON ALPHA-NUMERIC KEYS  ********************');
   insert_line('');

   output_key_family(' ');
   output_key_family('BACKSPACE');
   output_key_family('UP');
   output_key_family('DOWN');
   output_key_family('LEFT');
   output_key_family('RIGHT');
   output_key_family('ENTER');
   output_key_family('TAB');
   output_key_family('HOME');
   output_key_family('END');
   output_key_family('PGUP');
   output_key_family('PGDN');
   output_key_family('DEL');
   output_key_family('INS');
   output_key_family('[');
   output_key_family(']');
   output_key_family(',');
   output_key_family('.');
   output_key_family('/');
   output_key_family('\');
   output_key_family(';');
   output_key_family("'");
   output_key_family('=');
   output_key_family('-');
   output_key_family('`');
   output_key_family('PAD-PLUS');
   output_key_family('PAD-MINUS');
   output_key_family('PAD-STAR');
   output_key_family('PAD-SLASH');
   output_key_family('PAD5');

   insert_line('  // ********************  LETTERS  ********************');
   insert_line('');
   for (k = 0; k < 26; ++k) {
      output_key_family(_chr(k + 0x41));
   }

   insert_line('  // ********************  NUMBERS  ********************');
   insert_line('');
   for (k = 0; k < 10; ++k) {
      output_key_family(_chr(k + 0x30));
   }

   top();
}


static int kbt_menu_handle;

static add_key_to_menu(_str keyname)
{
   _str s = get_key_binding_name(keyname);
   if (s != '')  {
      _menu_insert(kbt_menu_handle, 0, MF_ENABLED, substr(keyname,1,15) :+ '  ' :+ s, s,"","",s);
   }
}


static generate_key_family_menu(_str base_key)
{
   add_key_to_menu('C-A-S-' :+ base_key);
   add_key_to_menu('C-A-' :+ base_key);
   add_key_to_menu('A-S-' :+ base_key);
   add_key_to_menu('C-S-' :+ base_key);
   add_key_to_menu('A-' :+ base_key);
   add_key_to_menu('C-' :+ base_key);
   add_key_to_menu('S-' :+ base_key);
   add_key_to_menu(base_key);
}


_menu XUN(xxkey_binding_trainer_menu) {
}


_command void XUN(xxkey_binding_trainer)() name_info(',')
{
   int index=find_index( XUNS "xxkey_binding_trainer_menu",oi2type(OI_MENU));
   if (!index) {
      return;
   }
   kbt_menu_handle=_menu_load(index,'P');
   message('Press a key');

   _str keyname = event2name(get_event());
   
   generate_key_family_menu(keyname);

   // Show the menu.
   int x = 100;
   int y = 100;
   x = mou_last_x('M')-x;y=mou_last_y('M')-y;
   _lxy2dxy(p_scale_mode,x,y);
   _map_xy(p_window_id,0,x,y,SM_PIXEL);
   int flags=VPM_LEFTALIGN|VPM_RIGHTBUTTON;
   int status=_menu_show(kbt_menu_handle,flags,x,y);
   _menu_destroy(kbt_menu_handle);

   // set the focus back
   if (_mdi.p_child._no_child_windows()==0) {
      _mdi.p_child._set_focus();
   }
}


//============================================================================================
//
//============================================================================================




static void show_xretrace_xxutils_help()
{
   //shell( get_env('SystemRoot') :+ '\explorer.exe /n,/e,/select,' :+ XRETRACE_PATH :+ 'xretrace-xxutils-help.pdf', 'A' );

   filename := XXUTILS_PATH :+ "xretrace-xxutils-help.pdf";
   cmd := "";
   if (_isWindows()) {
      cmd = 'start';
   } else if (_isLinux()) {
      cmd = 'xdg-open';
   } else {
      cmd = 'open';
   }
   rc := shell(cmd' '_maybe_quote_filename(filename));
   message("xretrace version " :+ XRETRACE_VERSION);
   //edit(_maybe_quote_filename(XRETRACE_MODULE_NAME));
   //goto_line(XRETRACE_SETTINGS_HELP_LINE);
}



_command void XUN(check_xtemp_new_temporary_file)() name_info(',')
{
   int xx1 = find_index("xtemp_new_temporary_file", COMMAND_TYPE);
   if ( index_callable(xx1) ) {
      xtemp_new_temporary_file();
   }
}


_command void XUN(check_xtemp_new_temporary_file_no_keep)() name_info(',')
{
   int xx1 = find_index("xtemp_new_temporary_file_no_keep", COMMAND_TYPE);
   if ( index_callable(xx1) ) {
      xtemp_new_temporary_file_no_keep();
   }
}


_command void XUN(check_start_xtemp_files_manager)() name_info(',')
{
   int xx1 = find_index("start_xtemp_files_manager", COMMAND_TYPE);
   if ( index_callable(xx1) ) {
      start_xtemp_files_manager();
   }
}


_command void XUN(check_stop_xtemp_files_manager)() name_info(',')
{
   int xx1 = find_index("stop_xtemp_files_manager", COMMAND_TYPE);
   if ( index_callable(xx1) ) {
      stop_xtemp_files_manager();
   }
}


_command void XUN(xxutils_help)() name_info(',')
{
   //int xx1 = find_index("show_xretrace_xxutils_help", PROC_TYPE);
   //if ( index_callable(xx1) ) {
   //   show_xretrace_xxutils_help();
   //}
   //else
   //   _message_box("xretrace must be loaded to see xxutils help");

   show_xretrace_xxutils_help();
}

_menu XUN(xmenu1) {
   "Set diff region", XUNS "xset_diff_region", "","","";
   "Compare diff region", XUNS "xcompare_diff_region", "","","";
   "Beautify project", XUNS "xbeautify_project", "","","";
   "Diff last two buffers",  XUNS "diff_last_two_buffers", "","","";

   "--","","","","";
   "&New temporary file",  XUNS "check_xtemp_new_temporary_file", "","","";
   submenu "&More","","","" {
      "Search &cplusplus.com", XUNS "search_cpp_ref", "", "", "";
      "Search &devdocs", XUNS "search_devdocs_cpp", "", "", "";
      "New temporary file no keep", XUNS "check_xtemp_new_temporary_file_no_keep", "","","";
      "Start xtemp file manager", XUNS "check_start_xtemp_files_manager","","",""; 
      "Stop xtemp file manager", XUNS "check_stop_xtemp_files_manager","","",""; 
      "&xnotepad cur line or selection", XUNS "xnotepad","","",""; 
      "xnotepad cur word", XUNS "xnotepad_word","","",""; 
      "xnotepad date-time", XUNS "xnotepad_create_time_date_string","","","";
      "Resize block selection", XUNS "xblock_resize_editor","","",""; 
      "Toggle &debug", XUNS "toggle_xxutils_debug","","",""; 
   }
   "--","","","","";
   "Transpose chars", "transpose_chars","","","";
   "Transpose words", "transpose_words","","","";
   "Transpose lines", "transpose_lines","","","";
   "Append word to clipboard", XUNS "xappend_word_to_clipboard","","","";
   submenu "Copy names ","","","" {
      "Copy cur buffer name to clipboard", XUNS "xcurbuf_name_to_clip","","",""; 
      "Copy cur buffer path+name to clipboard", XUNS "xcurbuf_path_to_clip","","",""; 
      "Copy active project name to clipboard", XUNS "xproject_name_to_clip","","",""; 
   }
   submenu "&Key bindings ","","","" {
      "Show key &family", XUNS "xxkey_binding_trainer","","",""; 
      "Show &all key family", XUNS "xxkey_bindings_show","","",""; 
      "Find &source code for command", "find_key_binding","","",""; 
      "Key &bindings dialog", "gui_keybindings","","",""; 
   }
   "--","","","","";
   "Alternate last 2 buffers", XUNS "alternate_buffers","","",""; 
   "Float &1", XUNS "xfloat1","","",""; 
   "Float &2", XUNS "xfloat2","","",""; 
   "Float &3", XUNS "xfloat3","","",""; 
   submenu "Set float","","","" {
      "Float &1", XUNS "xset_float1","","",""; 
      "Float &2", XUNS "xset_float2","","",""; 
      "Float &3", XUNS "xset_float3","","",""; 
   }
   "Save app layout", XUNS "xsave_named_toolwindow_layout","","",""; 
   "Restore app layout", XUNS "xload_named_toolwindow_layout","","",""; 

   #if __VERSION__  >=  23
   "Save session", "save_named_state","","",""; 
   "Restore session", "load_named_state","","",""; 
   #endif

   "--","","","","";

   submenu "&Bookmarks","","","" {
      "&Save bookmarks", XUNS "xsave_bookmarks","","",""; 
      "&Restore bookmarks", XUNS "xrestore_bookmarks","","",""; 
   }

   submenu "Com&plete","","","" {
      "complete-prev-no-dup", "complete_prev_no_dup","","","";
      "complete-next-no-dup", "complete_next_no_dup","","","";
      "complete-prev", "complete_prev","","","";
      "complete-next", "complete_next","","","";
      "complete-list", "complete_list","","","";
      "complete-more", "complete_more","","","";
   }

   submenu "&Select / Hide","","","" {
      "select code block",  "select_code_block","","","";
      "select paren",  "select_paren_block","","","";
      "select procedure",  "select_proc", "","","";
      "hide code block",  "hide_code_block","","","";
      "hide selection",  "hide_selection","","","";
      "hide comments",  "hide_all_comments","","","";
      "show all","show_all","","","";
   }

   submenu "&Open / E&xplore","","open-file or explore folder","" {
      "Open from here", XUNS "xopen_from_here","","","open from current buffer path";
      "Open from config", XUNS "xopen_from_config","","","open file from configuration folder";
      "Edit vsstack error file", XUNS "xopvss","","","Open Slick C error file";
      "Edit Slick logs", XUNS "xopen_logs","","","Open Slick log files";
      "-","","","","";
      "Explore current buffer", XUNS "explore_cur_buffer","","","explore folder of current buffer";
      "Explore config folder", XUNS "explore_config","","",""; 
      "Explore installation folder", XUNS  "explore_vslick","","",""; 
      "Explore docs", XUNS "explore_docs","","",""; 
      "Explore project", XUNS "explore_vpj","","","";
   }

   submenu "&Case conversion","","","" {
      "&Lowcase selection","lowcase_selection","","","";
      "&Upcase selection","upcase_selection","","","";
      "Lowcase word","lowcase_word","","","";
      "Upcase word","upcase_word","","","";
      "Upcase &char", XUNS "xupcase_char","","","";
      "Lowcase char", XUNS "xlowcase_char","","","";
      "Cap &selection","cap_selection", "","","";
   }
   #if 0
   submenu "Extra","","","" {
      "Decrease font size","decrease-font-size","","","";
      "Increase font size","increase-font-size","","","";
      "Toggle font","toggle-font","","","";
      "Save all","save-all-inhibit-buf-history","","","";
      "-","","","","";
      "&1 Function comment", "func-comment","","","";
   }
   #endif

   "&Help", XUNS "xxutils_help", "","","";

}

  
static int restore_bookmarks_from_file(_str filename)
{
   int new_wid, orig_wid;
   _str line;
   _str rest;

   orig_wid = p_window_id;
   int status = _open_temp_view(filename, new_wid, orig_wid);
   if (status) {
      _message_box('Unable to open bookmark file: ' :+ filename);
      p_window_id = orig_wid;
      return 1;
   }
   top();
   get_line(line);
   if (pos('BOOKMARK', line) != 0) {
      parse line with . ': ' rest;

      #if __VERSION__ >= 26
      _sr_bookmark3('R', rest);
      #else
      _sr_bookmark2('R', rest);
      #endif
   }
   else {
      status = 1;
   }
   _delete_temp_view(new_wid);
   p_window_id = orig_wid;
   return status;
}
  
  
static int save_all_bookmarks_to_file(_str &filename)
{
   bool b2;
   int new_wid, orig_wid;
   _str line;
   int rest;

   orig_wid = p_window_id;
   int status = _open_temp_view(filename, new_wid, orig_wid,'', b2, false, false, 0, true);
   if (status) {
      _message_box('Unable to open file: ' :+ filename);
      p_window_id = orig_wid;
      return 1;
   }
   //say(p_buf_name);
   delete_all();

   #if __VERSION__ >= 26
   _sr_bookmark3('S');
   #else
   _sr_bookmark2('S');
   #endif

   save();
   _delete_temp_view(new_wid);
   p_window_id = orig_wid;
   return 0;
}
  
  
static void xsave_and_clear_bookmarks(_str filename = null) 
{
   if (filename != null) {
      if (!path_exists(strip_filename(filename,'N'))) {
         make_path(strip_filename(filename,'N'));
      }
   }
   _str fn = _OpenDialog('', 'Save bookmarks to :','','', OFN_SAVEAS,'', strip_filename(filename,'P'), 
                               strip_filename(filename,'N'), 'RetrieveSaveBookmarks');
   if (fn == '') 
      return;
   if (save_all_bookmarks_to_file(fn))
      return;
   int result =_message_box("Bookmarks have been saved to:\n" :+ fn :+ "  \n\nDelete all bookmarks?",
                              '', MB_YESNO|MB_ICONQUESTION);
   if (result == IDYES) {
      clear_bookmarks('quiet');
   } 
}
  

static void xclear_and_restore_bookmarks(_str filename = null) 
{
   _str fn = _OpenDialog('', 'Load bookmarks from :','','','','', strip_filename(filename,'P'), 
                               strip_filename(filename,'N'), 'RetrieveSaveBookmarks');
   if (fn == '') 
      return;
   if (restore_bookmarks_from_file(fn) == 0)
      _message_box("Bookmarks have been restored from :\n" :+ fn :+ '   ');
}
  
  
_command void XUN(xsave_bookmarks)() name_info(',')
{
   xsave_and_clear_bookmarks(_config_path() :+ 'Bookmarks' :+ FILESEP :+ 'bookmarks-file1.bmk');
}


_command void XUN(xrestore_bookmarks)() name_info(',')
{
   xclear_and_restore_bookmarks(_config_path() :+ 'Bookmarks' :+ FILESEP :+ 'bookmarks-file1.bmk');
}



_str my_current_layout_import_settings_part1(int view_id)
{
   error := '';
   typeless count = 0;
   typeless line = "";
   _str type = "";
   top();
   for (;;) {
      // get the line - it will tell us what this section is for
      get_line(line);
      parse line with type line;

      name := '_sr_' :+ strip(lowcase(type), '', ':');
      index := find_index(name, PROC_TYPE);
      if (index_callable(index)) {
         status := call_index('R', line, index);
         if (status) {
            error = 'Error applying layout type 'type'.  Error code = 'status'.';
            break;
         }
      } else {
         error = 'No callback to apply layout type 'type'.' :+ OPTIONS_ERROR_DELIMITER;
         // we can't process these lines, so skip them
         parse line with count .;
         if (isnumber(count) && count > 1) {
            down(count-1);
         }
      }
      activate_window(view_id);
      if ( down()) {
         break;
      }
   }

   /********************************************************************************* 
    
   The following is done by the call to the real _current_layout_import_settings 
    
   if ( _tbFullScreenQMode() ) {
      if ( _tbDebugQMode() ) {
         if ( _tbDebugQSlickCMode() ) {
            _autorestore_from_view(_fullscreen_slickc_debug_layout_view_id, true);
         } else {
            _autorestore_from_view(_fullscreen_debug_layout_view_id, true);
         }
      } else {
         _autorestore_from_view(_fullscreen_layout_view_id, true);
      }
   } else {
      if ( _tbDebugQMode() ) {
         if ( _tbDebugQSlickCMode() ) {
            _autorestore_from_view(_slickc_debug_layout_view_id, true);
         } else {
            _autorestore_from_view(_debug_layout_view_id, true);
         }
      } else {
         _autorestore_from_view(_standard_layout_view_id, true);
      }
   } 
   p_window_id = view_id;
   ***********************************************************************************/

   return error;
}


int _sr_nothing()
{
   return 0;
}



// handle deletion of a layout from either the save or load dialog
static _str _load_named_twlayout_callback(int reason, var result, _str key)
{
   _nocheck _control _sellist;
   _nocheck _control _sellistok;
   if (key == 4) {
      item := _sellist._lbget_text();
      filename := _ConfigPath():+'xtoolwindow-layouts.ini';
      status := _ini_delete_section(filename,item);
      if ( !status ) {
         _sellist._lbdelete_item();
      }
   }
   return "";
}


// make sure the file xtoolwindow-layouts.ini is NOT open in the editor
// when this command is used
_command void XUN(xload_named_toolwindow_layout)(_str sectionName="") name_info(',')
{
   if (_version_compare(_version(), "23.0.0.0") > 0)  {
      // version 23 onwards have a built in command
      load_named_layout();
      return;
   }

   filename := _ConfigPath():+'xtoolwindow-layouts.ini';
   if ( sectionName=="" ) {
      _ini_get_sections_list(filename,auto sectionList);
      result := show('-modal _sellist_form',
                     "Load Named Layout",
                     SL_SELECTCLINE,
                     sectionList,
                     "Load,&Delete",     // Buttons
                     "Load Named Layout", // Help Item
                     "",                 // Font
                     _load_named_twlayout_callback
                     );
      if ( result=="" ) {
         return;
      }
      sectionName = result;
   }
   status := _ini_get_section(filename, sectionName, auto tempWID);
   if (status)
   {
      _message_box('Error reading file : ' :+ filename);
      return;
   }

   origWID := p_window_id;
   p_window_id = tempWID;

   _str err = my_current_layout_import_settings_part1(tempWID);
   if ( err != '' ) {
      _message_box(err);
   }

   filename = _ConfigPath() :+ 'xtemp' :+ FILESEP :+ 'nothing.slk';

   // pass a dummy file containing one line only so that the calls to _autorestore_from_view get done
   _current_layout_import_settings(filename);

   if ( _iswindow_valid(tempWID) ) {
      _delete_temp_view(tempWID);
   }

   if ( _iswindow_valid(origWID) ) {
      p_window_id = origWID;
   }
}

// make sure the file xtoolwindow-layouts.ini is NOT open in the editor
// when this command is used
_command void XUN(xsave_named_toolwindow_layout)(_str sectionName="") name_info(',')
{
   if (_version_compare(_version(), "23.0.0.0") > 0)  {
      // version 23 onwards have a built in command
      save_named_layout();
      return;
   }

   filename := _ConfigPath():+'xtoolwindow-layouts.ini';
   if ( sectionName=="" ) {
      _ini_get_sections_list(filename,auto sectionList);
      result := "";
      if ( sectionList==null ) {
         // if there are no section names stored already, prompt for a name.
         result = textBoxDialog("Save Named Layout",
                                0,
                                0,
                                "Save Named Layout",
                                "",
                                "",
                                "Save Named Layout");
         if ( result==COMMAND_CANCELLED_RC ) {
            return;
         }
         result = _param1;
      } else {
         // if there are names, show the list with a combobox so they can pick or type a new name.
         result = show('-modal _sellist_form',
                       "Save Named Layout",
                       SL_SELECTCLINE|SL_COMBO,
                       sectionList,
                       "Save,&Delete",     // Buttons
                       "Save Named Layout", // Help Item
                       "",                 // Font
                       _load_named_twlayout_callback
                       );
      }
      if ( result=="" ) return;
      sectionName = result;
   }
   int orig_view_id = _create_temp_view(auto temp_view_id);
   _sr_app_layout();
   _sr_standard_layout();
   _sr_fullscreen_layout();
   _sr_debug_layout();
   _sr_fullscreen_debug_layout();
   _sr_slickc_debug_layout();
   _sr_fullscreen_slickc_debug_layout();

   p_window_id = orig_view_id;
   int status = _ini_put_section(filename, sectionName, temp_view_id);
   if (status) {
      _message_box('Error writing file : ' :+ filename);
   }
}


struct xwin_data {
   int px;
   int py;
   int pw;
   int ph;
   _str layout_name;
};

xwin_data xfloat_data[];


static void save_xuser_data()
{
   _str filename = _ConfigPath():+'xuser-data.ini';

   if ( xfloat_data._length() == 0 ) {
      xfloat_data[0].px = 200;
      xfloat_data[0].py = 200;
      xfloat_data[0].pw = 500;
      xfloat_data[0].ph = 500;
      xfloat_data[0].layout_name = 'Standard';
      xfloat_data[1] = xfloat_data[0];
      xfloat_data[2] = xfloat_data[0];
   }
   else if ( xfloat_data._length() == 1 ) {
      xfloat_data[1] = xfloat_data[0];
      xfloat_data[2] = xfloat_data[0];
   }
   else if ( xfloat_data._length() == 2 ) {
      xfloat_data[2] = xfloat_data[0];
   }

   int orig_view_id = _create_temp_view(auto temp_view_id);
   int k;
   for ( k = 0; k < xfloat_data._length(); ++k ) {
            insert_line('float' :+ k+1 :+ ' ' 
                                  :+ xfloat_data[k].px :+ ' '
                                  :+ xfloat_data[k].py :+ ' '  
                                  :+ xfloat_data[k].pw :+ ' '  
                                  :+ xfloat_data[k].ph :+ ' '  
                                  :+ xfloat_data[k].layout_name );
   }
   p_window_id = orig_view_id;
   int status = _ini_put_section(filename, 'Floating-edit-window-pos', temp_view_id);
   if (status) {
      _message_box('Error writing file : ' :+ filename);
   }
}


static void load_xuser_data()
{
   _str filename = _ConfigPath():+'xuser-data.ini';
   status := _ini_get_section(filename, 'Floating-edit-window-pos', auto tempWID);
   if (status)
   {
      //_message_box('Error reading file : ' :+ filename);
      return;
   }

   origWID := p_window_id;
   p_window_id = tempWID;
   xfloat_data._makeempty();
   top();
   _str line = '';
   int k = 0;
   for ( ; k < 3; ++k ) {
      get_line(line);
      _str s0, s1, s2, s3, s4, s5;
      parse line with s0 s1 s2 s3 s4 s5 .;
      xfloat_data[k].px = (int)s1;  
      xfloat_data[k].py = (int)s2; 
      xfloat_data[k].pw = (int)s3; 
      xfloat_data[k].ph = (int)s4;
      xfloat_data[k].layout_name = s5;
      if (down())
         break;
   }
   p_window_id = origWID;
}



// _MDICurrent
// _MDIFromChild
// _MDICurrentFloating

#ifndef CURRENT_LAYOUT_PROPERTY
#define CURRENT_LAYOUT_PROPERTY  'CurrentLayout'
#endif



_command void XUN(xset_float1)() name_info(','VSARG2_REQUIRES_MDI_EDITORCTL|VSARG2_READ_ONLY)
{
   if (_no_child_windows()) {
      return;
   }
   save_all();

   result = _message_box("Please ensure you have at least one floating" :+ 
                "\nedit window before using this command." :+
                "\n\nDo you want to proceed?", '', IDYES|IDNO|MB_ICONQUESTION,IDNO);

   if ( result != IDYES ) {
      message("Command cancelled");
      return;
   }

   xxdebug("mdi", _MDICurrentFloating(), _MDICurrent(), _mdi.p_child, GetEditorCtlWid(p_active_form));

   wid := _MDICurrent();
   //wid := GetEditorCtlWid(p_active_form);
   if ( wid ) {
      xfloat_data[0].px = wid.p_x;
      xfloat_data[0].py = wid.p_y;
      xfloat_data[0].pw = wid.p_width;
      xfloat_data[0].ph = wid.p_height;
      _str layout;
      _MDIGetUserProperty(wid, CURRENT_LAYOUT_PROPERTY, layout);
      xfloat_data[0].layout_name = layout;
      save_xuser_data();
      xxdebug("xs1 px py pw ph", wid.p_x, wid.p_y, wid.p_width, wid.p_height, xfloat_data[0].layout_name);
   }
}


_command void XUN(xset_float2)() name_info(','VSARG2_REQUIRES_MDI_EDITORCTL|VSARG2_READ_ONLY)
{
   if (_no_child_windows()) {
      return;
   }
   save_all();

   result = _message_box("Please ensure you have at least one floating" :+ 
                "\nedit window before using this command." :+
                "\n\nDo you want to proceed?", '', IDYES|IDNO|MB_ICONQUESTION,IDNO);

   if ( result != IDYES ) {
      message("Command cancelled");
      return;
   }

   wid := _MDICurrent();
   if ( wid ) {
      xfloat_data[1].px = wid.p_x;
      xfloat_data[1].py = wid.p_y;
      xfloat_data[1].pw = wid.p_width;
      xfloat_data[1].ph = wid.p_height;
      _str layout;
      _MDIGetUserProperty(wid, CURRENT_LAYOUT_PROPERTY, layout);
      xfloat_data[1].layout_name = layout;
      save_xuser_data();
   }
}


_command void XUN(xset_float3)() name_info(','VSARG2_REQUIRES_MDI_EDITORCTL|VSARG2_READ_ONLY)
{
   if (_no_child_windows()) {
      return;
   }
   save_all();

   result = _message_box("Please ensure you have at least one floating" :+ 
                "\nedit window before using this command." :+
                "\n\nDo you want to proceed?", '', IDYES|IDNO|MB_ICONQUESTION,IDNO);

   if ( result != IDYES ) {
      message("Command cancelled");
      return;
   }

   wid := _MDICurrent();
   if ( wid ) {
      xfloat_data[2].px = wid.p_x;
      xfloat_data[2].py = wid.p_y;
      xfloat_data[2].pw = wid.p_width;
      xfloat_data[2].ph = wid.p_height;
      _str layout;
      _MDIGetUserProperty(wid, CURRENT_LAYOUT_PROPERTY, layout);
      xfloat_data[2].layout_name = layout;
      save_xuser_data();
   }
}


static int GetEditorCtlWid(int wid)
{
   if (_no_child_windows()) 
      return -1;
   int editorctl_wid = wid._MDIGetActiveMDIChild();
   if ( editorctl_wid != null && _iswindow_valid(editorctl_wid) && editorctl_wid._isEditorCtl()) {
      return editorctl_wid;
   }
   return _mdi.p_child;
}



_command void XUN(xfloat1)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_MDI_EDITORCTL)
{
   if (_no_child_windows()) {
      return;
   }
   int wid = p_window_id; // The name_info() args above guarantee p_window_id is an editor control

   float_window();
   if ( xfloat_data._length() < 1 ) {
      _message_box('Call xset_float1 to set window pos and layout.');
      return;
   }
   int mdi = _MDIFromChild(wid);  
   if ( mdi > 0 ) {
      mdi.p_x =           xfloat_data[0].px;
      mdi.p_y =           xfloat_data[0].py;
      mdi.p_width =       xfloat_data[0].pw;
      mdi.p_height =      xfloat_data[0].ph;

      mdisetfocus(mdi);  // this is required so that applyLayout works
      //tw_clear(mdi);   // tw_clear is alternative to setfocus
      if ( _MDICurrent() == mdi ) {
         applyLayout(xfloat_data[0].layout_name);
      }
      xxdebug("px py pw ph", xfloat_data[0].px, mdi.p_x, mdi.p_y, mdi.p_width, mdi.p_height, xfloat_data[0].layout_name);
   }
}


_command void XUN(xfloat2)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_MDI_EDITORCTL)
{
   if (_no_child_windows()) {
      return;
   }
   int wid = p_window_id; // The name_info() args above guarantee p_window_id is an editor control
   float_window();

   if ( xfloat_data._length() < 2 ) {
      _message_box('Call xset_float2 to set window pos and layout.');
      return;
   }

   int mdi = _MDIFromChild(wid);  
   if ( mdi > 0 ) {
      mdi.p_x =           xfloat_data[1].px;
      mdi.p_y =           xfloat_data[1].py;
      mdi.p_width =       xfloat_data[1].pw;
      mdi.p_height =      xfloat_data[1].ph;

      mdisetfocus(mdi);  // this is required so that applyLayout works
      //tw_clear(mdi);   // tw_clear is alternative to setfocus
      if ( _MDICurrent() == mdi ) {
         applyLayout(xfloat_data[1].layout_name);
      }
      xxdebug("px py pw ph", xfloat_data[1].px, mdi.p_x, mdi.p_y, mdi.p_width, mdi.p_height, xfloat_data[1].layout_name);
   }
}


_command void XUN(xfloat3)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_MDI_EDITORCTL)
{
   if (_no_child_windows()) {
      return;
   }
   int wid = p_window_id; // The name_info() args above guarantee p_window_id is an editor control

   float_window();
   if ( xfloat_data._length() < 3 ) {
      _message_box('Call xset_float3 to set window pos and layout.');
      return;
   }
   int mdi = _MDIFromChild(wid);  
   if ( mdi > 0 ) {
      mdi.p_x =           xfloat_data[2].px;
      mdi.p_y =           xfloat_data[2].py;
      mdi.p_width =       xfloat_data[2].pw;
      mdi.p_height =      xfloat_data[2].ph;

      mdisetfocus(mdi);  // this is required so that applyLayout works
      //tw_clear(mdi);   // tw_clear is alternative to setfocus
      if ( _MDICurrent() == mdi ) {
         applyLayout(xfloat_data[2].layout_name);
      }
      xxdebug("px py pw ph", xfloat_data[2].px, mdi.p_x, mdi.p_y, mdi.p_width, mdi.p_height, xfloat_data[2].layout_name);
   }
}


_command void XUN(xappend_word_to_clipboard)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   select_whole_word();
   append_to_clipboard();
}

static bool IsGotoNextBuffer=true;
_command void XUN(alternate_buffers)() name_info(','VSARG2_REQUIRES_MDI_EDITORCTL|VSARG2_READ_ONLY)
{
   if (IsGotoNextBuffer) {
      back();            
   } else {               
      forward();         
   }                      
   IsGotoNextBuffer = !IsGotoNextBuffer;
}




// This macro requires google chrome browser and opens the cplusplus.com website at the cpp page
// with the word at the cursor searched for
_command void XUN(search_cpp_ref)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   _str sw = get_search_cur_word();
   if (sw == '') 
      return;

   goto_url("http://www.google.com/search?q=" :+ sw :+ "&as_sitesearch=cplusplus.com&btnI");
}


// This macro requires google chrome browser and opens the devdocs.io website at the cpp page
// with the word at the cursor on the system clipboard
_command void XUN(search_devdocs_cpp)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   _str sw = get_search_cur_word();
   if (sw == '') 
      return;

   push_clipboard_itype('CHAR','',1,true);
   append_clipboard_text(sw);
   goto_url("https://devdocs.io/cpp/");
}

//=================================================================================================
// diff2 borrowed from SlickTeam
//=================================================================================================
static _str last_buffer = '';
static _str second_last_buffer = '';

/**
 * @author Ryan Anderson
 * @version 0.2 - 2005/02/24
 * @description Sets the following global static varibles to the correct values:
 *       last_buffer
 *       second_last_buffer
 */
void _switchbuf_last_two_buffers(_str oldbuffname, _str flags)
{
   // Use _mdi.p_child.p_buf_name instead of just p_buf_name
   // to prevent picking up unwanted hidden buffers
   _str possible_last_buffer = _mdi.p_child.p_buf_name;
   // Extra checks to prevent getting incorrect buffers
   if (p_buf_flags & HIDE_BUFFER)                            { return; }
   if (possible_last_buffer == last_buffer)                  { return; }
   if (possible_last_buffer == '')                           { return; }
   if (possible_last_buffer == '.command')                   { return; }
   if (possible_last_buffer == '.process')                   { return; }
   if (possible_last_buffer == '.slickc_stack')              { return; }
   if (possible_last_buffer == '.References Window Buffer')  { return; }
   if (possible_last_buffer == '.Tag Window Buffer')         { return; }
   second_last_buffer = last_buffer;
   last_buffer        = possible_last_buffer;
}

/**
 * @author Ryan Anderson
 * @version 0.2 - 2005/02/24
 * @returns The return value from 'diff'
 *       0 if successful, Otherwise a nonzero error code
 * @description Runs a diff on the last 2 buffers that were selected
 *       If 2 buffers were not yet selected, it just brings up the regular diff window
 */
_command int XUN(diff2),XUN(diff_last_two_buffers)() name_info(',' VSARG2_REQUIRES_EDITORCTL | VSARG2_MARK | VSARG2_READ_ONLY)
{
   int result = -99;
   if (last_buffer == '') { 
      _message_box("You must open 2 files to run this command.", "Message - diff_last_two_buffers");
      result = diff();
      return(result);
   }
   if (second_last_buffer == '') { 
      _message_box("You must switch to a second buffer to diff this buffer with.", "Message - diff_last_two_buffers");
      result = diff();
      return(result);
   }
   result = diff(_maybe_quote_filename(last_buffer)" "_maybe_quote_filename(second_last_buffer));
   return(result);
}

//=================================================================================================



_command void XUN(show_xmenu1)() name_info(',')
{
   mou_show_menu(XUNS 'xmenu1');
}



//========================================================================================
// cursor movement, selection functions
//========================================================================================



static bool is_wordchar(_str s1)
{
   return _clex_is_identifier_char(s1);

   //return isalnum(s1) || (s1=='_');
   //return pos('['p_word_chars']',s1,1,'R') > 0;

   // _clex_identifier_chars   _clex_is_identifier_char
}


static bool is_whitespace(_str s1)
{
   return (s1==' ') || (s1==\n) || (s1==\t) || (s1==\r) ;
}


/* xcursor_to_next_token_stop_on_all
   - skips whitespace,
   - stops at start of a word,
   - stops on any other non whitespace char
*/
_command void XUN(xcursor_to_next_token_stop_on_all)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MULTI_CURSOR)
{
   int lim = 0;
   if ( is_wordchar(get_text()) ) {
      while ( is_wordchar(get_text()) ) {
         if (++lim > 2000)
            return;
         cursor_right();
      }
   } else {
      cursor_right();
   }
   lim = 0;
   _str s1 = get_text();
   while ( is_whitespace(s1) ) {
      if (++lim > 2000)
         return;
      if ((s1==\n) || (s1==\r)) {
         begin_line();
         cursor_down();
      } else {
         cursor_right();
      }
      s1 = get_text();
   }
}



/* xcursor_to_prev_token_stop_on_all
   - skips whitespace,
   - stops at start of a word,
   - stops on any other non whitespace char
*/
_command void XUN(xcursor_to_prev_token_stop_on_all)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MULTI_CURSOR)
{
   int lim = 0;
   cursor_left();
   while ( is_whitespace(get_text()) ) {
      if (++lim > 2000)
         return;
      cursor_left();
      if (get_text()==\r) {
         return;
      }
   }
   lim = 0;
   if ( is_wordchar(get_text()) ) {
      while ( is_wordchar(get_text()) ) {
         if (++lim > 2000)
            return;
         cursor_left();
      }
      cursor_right();
   }
}




/* xcursor_to_next_token
   - stops at start and end of a word
*/
_command void XUN(xcursor_to_next_token)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MULTI_CURSOR)
{
   int lim = 0;
   if ( is_wordchar(get_text()) ) {
      while ( is_wordchar(get_text()) ) {
         if (++lim > 2000)
            return;
         cursor_right();
      }
      return;
   } else {
      while ( !is_wordchar(get_text()) ) {
         if (++lim > 2000)
            return;
         cursor_right();
      }
      return;
   }
}


// This works too
// _command void xcursor_to_next_token2() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
// {
//    already_looping := _MultiCursorAlreadyLooping();
//    multicursor := !already_looping && _MultiCursor();
//    for (ff:=true;;ff=false) {
//       if (_MultiCursor()) {
//          if (!_MultiCursorNext(ff)) {
//             break;
//          }
//       }
//       XUN(xcursor_to_next_token)();
//       if (!multicursor) {
//          if (!already_looping) _MultiCursorLoopDone();
//          break;
//       }
//    }
// }




/* xcursor_to_prev_token
   - stops at start and end of a word
*/
_command void XUN(xcursor_to_prev_token)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MULTI_CURSOR)
{
   int lim = 0;
   cursor_left();
   if ( is_wordchar(get_text()) ) {
      while ( is_wordchar(get_text()) ) {
         if (++lim > 2000)
            return;
         cursor_left();
      }
      cursor_right();
      return;
   } else {
      while ( !is_wordchar(get_text()) ) {
         if (++lim > 2000)
            return;
         cursor_left();
      }
      cursor_right();
      return;
   }
}


// This works too
//_command void xcursor_to_prev_token2() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
//{
//   already_looping := _MultiCursorAlreadyLooping();
//   multicursor := !already_looping && _MultiCursor();
//   for (ff:=true;;ff=false) {
//      if (_MultiCursor()) {
//         if (!_MultiCursorNext(ff)) {
//            break;
//         }
//      }
//      XUN(xcursor_to_prev_token)();
//      if (!multicursor) {
//         if (!already_looping) _MultiCursorLoopDone();
//         break;
//      }
//   }
//}


_command void XUN(xselect_to_next_token)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK|VSARG2_MULTI_CURSOR)
{
   _select_char();
   XUN(xcursor_to_next_token)();  // this function also has VSARG2_MULTI_CURSOR
   _select_char();
}



_command void XUN(xselect_to_prev_token)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK|VSARG2_MULTI_CURSOR)
{
   _select_char();
   XUN(xcursor_to_prev_token)();  // this function also has VSARG2_MULTI_CURSOR
   _select_char();
}

static _str  the_word;


_command void XUN(xfind_next_whole_word_at_cursor)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   int lim = 0;
   if ( !is_wordchar(get_text()) ) {
      cursor_left();
      if (!is_wordchar(get_text())) {
         while ( !is_wordchar(get_text()) ) {
            XUN(xcursor_to_next_token)();
            if (++lim > 2000)
               return;
         }
         return;
      }
   }
   lim = 0;
   the_word = '';
   while ( is_wordchar(get_text()) ) {
      cursor_left();
      if (++lim > 2000)
         return;
   }
   cursor_right();
   while ( is_wordchar(get_text()) ) {
      the_word = the_word :+ get_text();
      cursor_right();
      if (++lim > 2000)
         return;
   }
   if ( find(the_word,'IHPW') == 0 ) {
      _deselect();
      _select_char();
      cursor_right(length(the_word));
      _select_char();
      cursor_left(length(the_word));
      return;
   }
   top();
   message('***** wrapping to top *****');
   find(the_word,'IH');
}


_command void XUN(xfind_prev_whole_word_at_cursor)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   int lim = 0;
   if ( !is_wordchar(get_text()) ) {
      cursor_left();
      if (!is_wordchar(get_text())) {
         while ( !is_wordchar(get_text()) ) {
            XUN(xcursor_to_prev_token)();
            if (++lim > 2000)
               return;
         }
         return;
      }
   }
   lim = 0;
   the_word = '';
   while ( is_wordchar(get_text()) ) {
      cursor_left();
      if (++lim > 2000)
         return;
   }
   cursor_right();
   while ( is_wordchar(get_text()) ) {
      the_word = the_word :+ get_text();
      cursor_right();
      if (++lim > 2000)
         return;
   }
   XUN(xcursor_to_prev_token)();
   cursor_left();
   if ( find(the_word,'-IHPW') == 0 ) {
      _deselect();
      _select_char();
      cursor_right(length(the_word));
      _select_char();
      cursor_left(length(the_word));
      return;
   }
   bottom();
   message('***** wrapping to bottom now *****');
   find(the_word,'-IH');
}


static bool xquick_direction_is_fwd;

_command void XUN(xquick_search)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   _str tw;
   if (select_active2()) {
      tw = get_search_cur_word();
      end_select();
      cursor_right();
      if (tw && tw == the_word && xquick_direction_is_fwd)
      {
         if (find_next() == 0) {
            _deselect();
            _select_char();
            cursor_right(length(the_word));
            _select_char();
            cursor_left(length(the_word));
            return;
         }
      }
      xquick_direction_is_fwd = true;
      if ( tw ) {
         push_bookmark();
         the_word = tw;
         if ( find(tw,'IHP') == 0 ) {
            _deselect();
            _select_char();
            cursor_right(length(the_word));
            _select_char();
            cursor_left(length(the_word));
            return;
         }
         pop_bookmark();
      }
   }
   xquick_direction_is_fwd = true;
   push_bookmark();
   XUN(xfind_next_whole_word_at_cursor)();
}


_command void XUN(xquick_reverse_search)() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   _str tw;
   if (select_active2()) {
      tw = get_search_cur_word();
      begin_select();
      cursor_left();
      if (tw)
      {
         if ( tw == the_word && !xquick_direction_is_fwd ) {
            if (find_next() == 0) {
               _deselect();
               _select_char();
               cursor_right(length(the_word));
               _select_char();
               cursor_left(length(the_word));
               return;
            }
         }
         else
         {
            xquick_direction_is_fwd = false;
            push_bookmark();
            the_word = tw;
            if ( find(tw,'-IHP') == 0 ) {
               _deselect();
               _select_char();
               cursor_right(length(the_word));
               _select_char();
               cursor_left(length(the_word));
               return;
            }
            pop_bookmark();
         }
      }
   }
   xquick_direction_is_fwd = false;
   push_bookmark();
   XUN(xfind_prev_whole_word_at_cursor)();
}


_command void XUN(xdelete_next_token)(bool leave_a_space = true) name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_MULTI_CURSOR)
{
   _deselect();
   if (is_wordchar(get_text())) {
      delete_word();
      return;
   }
   if (leave_a_space) {
      _str s1 = get_text();
      if (is_whitespace(s1) && (p_col > 1) && s1!=\r && s1!=\n) {
         cursor_left();
         if (is_whitespace(get_text())) {
            // there is already whitespace before the current character so don't skip any
            cursor_right();
         } else {
            cursor_right();
            if (get_text(2) :== '  ')
               cursor_right(); // leave one whitespace character
         }
      }
   }
   XUN(xselect_to_next_token)();
   delete_selection();
}
 


_command void XUN(xdelete_prev_token)() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_MULTI_CURSOR)
{
   _deselect();
   _select_char();
   cursor_left();
   _str s1 = get_text();
   int lim = 0;
   if (is_whitespace(s1)) {
      while (is_whitespace(s1)) {
         if (s1==\r || s1 == \n) {
            _select_char();
            delete_selection();
            return;
         }
         if (++lim > 2000){
            _deselect();
            return;
         }
         cursor_left();
         s1 = get_text();
      }
      cursor_right();
      _select_char();
      delete_selection();
      return;
   }
   _deselect();
   cursor_right();
   XUN(xselect_to_prev_token)();
   delete_selection();
}


void _on_load_module_xxutils(_str module_name)
{
   _str sm = strip(module_name, "B", "\'\"");
   if (strip_filename(sm, 'PD') == "xxutils.ex") {
      xtemp_list_active = false;
      xtemp_kill_maintain_timer();
   }
}


// kill the timer, clear markers and release resources
void _on_unload_module_xxutils(_str module_name)
{
   _str sm = strip(module_name, "B", "\'\"");
   if (_strip_filename(sm, 'PD') == "xxutils.ex") {
      xtemp_list_active = false;
      xtemp_kill_maintain_timer();
   }
}


// slick is closing, save the list and discard no-keep files
void _exit_xtemp_handle_temporary_files()
{
   xtemp_wkspace_has_been_closed = false;
   xtemp_wkspace_has_been_opened = false;
   xtemp_list_regenerate_needed = false;
   if ( xtemp_list_active ) {
      xtemp_save_file_list_to_disk();
   }
   // this deletes the no-keep files but causes problems on restart
   //for_each_buffer('xtemp_maybe_discard_file');
}


definit()
{
   load_xuser_data();

   //xtemp_file_manager_definit()
   //{
      xtemp_ignore_cbquit = false;
      remember_temp_files_from_workspace._makeempty();
      xtemp_wkspace_has_been_opened = false;
      xtemp_wkspace_has_been_closed = false;

      xtemp_files_path = get_env('xtemp_files_path');
      if ( xtemp_files_path == '' ) {
         set_env('xtemp_files_path', XTEMP_FILES_PATH);
         xtemp_files_path = XTEMP_FILES_PATH;
      }

      xtemp_list_active = false;
      if ( arg(1) == 'L' ) {
         // this is a reload
         kill_xtemp_timer();
      }
      else
      {
         xtemp_list_maintain_timer = -1;
      }
   //}

}

