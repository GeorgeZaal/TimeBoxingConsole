program TimeBoxingConsole;

uses Crt, Timers, Sounds;

const
  max_tasks = 20;        // Максимальное количество задач
  max_task_name = 40;    // Максимальная длина имени задачи
  Tf_name = 'tasks.txt'; // Имя файла с задачами
  stroka_length = 50;    // Длина выводимой строки с задачей
  con_height = 25;       // Высота рабочей области программы. Напр., gotoxy(1,28) = gotoxy(1, con_height - 2)
  sel_col = 14;          // Цвет выделенной строки
  top_col = magenta;     // Цвет шапки
  main_time_x = 17;      // Положение главного счётчика

type item = record
  n : 1..max_tasks + 1;  // + 1 - Резервируем 21 пункт как пустой
  time : 1..999;
  name : string[max_task_name];
  select, run : boolean;
end;

type tablo = record
  hr, min, sec : integer;
end;

type tablo_str = record
  hr, min, sec : string[2];
end;

var 
  com : char;
  NewTask : string[max_task_name];
  i, tmr, LastItem, SelItem, ActiveItem, WorkItem : integer;
  itm : array[1..max_tasks + 1] of item; // + 1 - Резервируем 21 пункт как пустой
  play : boolean;
  t : timer;
  ful_time, main_time : tablo;
  ful_time_str, main_time_str : tablo_str;

procedure Tmr_Clr;
begin
  main_time.sec := 0;
  main_time.min := 0;
  main_time.hr := 0;
  main_time_str.sec := '00';
  main_time_str.min := '00';
  main_time_str.hr := '00';
  // Общий таймер, если надо, то удалить
  tmr := 0;
end;

// Процедура вывода текста:
procedure prnt(x, y, bgcolor, txtcolor : integer; msg : string);
begin
  gotoxy(x, y);
  textbackground(bgcolor);
  textcolor(txtcolor);
  writeln(msg);
  textbackground(0);
  textcolor(7);
end;

// Процедура подсчёта общего времени
procedure Total_Time;
var
  _i, t_time : integer;
  t_time_hour, t_time_min : string;
begin
  // Если заполненные пункты есть, то суммируем их время:
  if LastItem <> 0 then
    for _i := 1 to LastItem do 
	  t_time := t_time + itm[_i].time;
  // Если общее время больше часа:
  if t_time >= 60 then
  begin
    t_time_hour := inttostr(t_time div 60);
    t_time_min := inttostr(t_time - strtoint(t_time_hour)*60);
  end
  // Если общее время меньше часа:
  else
  begin
    t_time_hour := '00';
    t_time_min := inttostr(t_time);
  end;
  // Если нужно, добавляем нули:
  if length(t_time_hour) < 2 then 
    t_time_hour := '0' + t_time_hour;
  if length(t_time_min) < 2 then 
    t_time_min := '0' + t_time_min;
  // Выводим время:
  prnt(1, 1, top_col, white, t_time_hour + ':' + t_time_min + ' / ');
end;

// Процедура рисования шапки
procedure Draw_Top;
begin
  prnt(1, 1, top_col, white, '              │                                                                 ');  
end;

// Процедура покраски выделенного пункта:
procedure Brush_Sel;
begin
  if SelItem = 0 then 
    SelItem := 1; // Если создаётся первая задача, то сразу выделить первый пункт
  gotoxy(1, 2 + SelItem);
  textcolor(sel_col);
  writeln(itm[SelItem].n, ' ', itm[SelItem].name);
  textcolor(7);
end;

// Процедура очистки и ввода в строку ввода/вывода:
procedure IO_Print(msg : String);
begin
  gotoxy(1, con_height - 1);
  write('                                                                      ');  
  gotoxy(1, con_height - 1);
  write(msg);
end;

// Рисование стрелки:
procedure Draw_Active;
var 
  _i : integer;
begin
  for _i := 3 to LastItem + 2 do 
  begin
    // Очищаем поле
    gotoxy(stroka_length + 9, _i);
    write(' ');
  end;
  gotoxy(stroka_length + 9, ActiveItem + 3);
  if play = false then 
    write(':')
  else 
    write('>');
end;

// Функция проверки корректности записи вводимой/считываемой задачи
function Check_New_Task(NewTask : string): boolean;
var 
  _i, _t : integer;
  _time : string;
begin
  _time := Copy(NewTask, LastPos(' -- ', NewTask)+4, Length(NewTask) - (Pos(' -- ', NewTask)+3));     
  for _i := 1 to Length(_time) do
    case _time[_i] of '0'..'9' : inc(_t);
    end;  
// Условия несоответствия: 1) cлишком длинное описание задачи и/или 2) нет правильных тирешек 3) время - ноль  
  if (Length(NewTask) > 80) or 
    (Pos(' -- ', NewTask) = 0) or 
	(_time = '0') then 
	  Check_New_Task := false;
// Если 1) размер второй части выражения с цифрами больше 0 и меньше 4, 
// и 2) количество цифр во второй части равно само себе,
// значит, условия выполняются:
  if (Length(_time) > 0) and 
    (Length(_time) < 4) and 
	(Length(_time) = _t) then 
	  Check_New_Task := true;
  else 
    Check_New_Task := false;
end;

// Процедура добавления записи в первый чистый пункт
procedure Add_Task(NewTask : string);
var 
  _i : integer;
begin
  for _i := 1 to max_tasks do
    if itm[_i].name = '' then
    begin
      itm[_i].name := Copy(NewTask, 1, LastPos(' -- ', NewTask)-1); 
      itm[_i].time := StrToInt(Copy(NewTask, LastPos(' -- ', NewTask)+4, Length(NewTask) - (Length(itm[_i].name)+3)));           
      exit;
    end;
end;

// Процедура открытия файла с задачами
procedure Open_Tasks_File;
var
  _F : text;
  _st : string;
  _i : integer;
begin
  _i := 1;
  // Если файла нет, то создать:
  if FileExists(Tf_name) = false then 
    begin
      Assign(_F, Tf_name);
      ReWrite(_F);
      Close(_F);
      exit;
    end
    else
    begin
    // Если файл есть, то работать с ним:
      Assign(_F, Tf_name);
      Reset(_F);
      while (not EOF(_F)) do
        if _i <= max_tasks then
        begin
          ReadLn(_F, _st);
          if Check_New_Task(_st) = true then 
		    Add_Task(_st); // Проверяем запись и, если она корректная, вносим в пункт
          inc(_i);
        end
        else
          break;
    end;
  Close(_F);
end;

// Процедура сохранения файла с задачами
procedure Save_Tasks_File;
var
  _F : text;
  _st : string;
  _i : integer;
begin
  _i := 1;
  Assign(_F, Tf_name);
  ReWrite(_F);
  if itm[1].name <> '' then
    for _i := 1 to LastItem do 
    begin
      _st := itm[_i].name + ' -- ' + itm[_i].time;          
      WriteLn(_F, _st);
    end; 
  Close(_F);
end;

// Процедура вывода задач:
procedure Show_Items;
var 
  _i, _j, _k, _length_zap : integer;
  _dots : string;
begin
  gotoxy(1, 3);
  // 1. Если список задач пуст:
  if itm[1].name = '' then
  begin
    LastItem := 0;
    ActiveItem := 0;
    writeln('Дел нет');
  end;
  // 2. Если список забит до предела:
  if itm[max_tasks].name <> '' then
  begin
    LastItem := max_tasks; // + 1 ***
    for _i := 1 to max_tasks do 
    begin
      _length_zap := 0;
      _dots := '';
      if _i < 10 then 
      begin
        _length_zap := stroka_length - length(itm[_i].name);
        for _k := 1 to _length_zap do 
		  _dots := _dots + '.';
        writeln(itm[_i].n, ' ', itm[_i].name, ' ', _dots, ' ', itm[_i].time);
      end 
	  else
      begin
        _length_zap := stroka_length - 1 - length(itm[_i].name);
        for _k := 1 to _length_zap do 
		  _dots := _dots + '.';
        writeln(itm[_i].n, ' ', itm[_i].name, ' ', _dots, ' ', itm[_i].time);
      end;        
    end;
    Draw_Active;             
  end;
  // 3. Если есть заполненные задачи, но есть и пустые:
  if (itm[1].name <> '') and 
    (itm[max_tasks].name = '') then
  begin
    for _i := 1 to max_tasks do
      if itm[_i].name = '' then 
      begin
        LastItem := _i - 1;
        for _j := 1 to LastItem do 
        begin
          _length_zap := 0;
          _dots := '';
          if _j < 10 then 
          begin
            _length_zap := stroka_length - length(itm[_j].name);
            for _k := 1 to _length_zap do 
			  _dots := _dots + '.';
            writeln(itm[_j].n, ' ', itm[_j].name, ' ', _dots, ' ', itm[_j].time);
          end 
		  else
          begin
            _length_zap := stroka_length - 1 - length(itm[_j].name);
            for _k := 1 to _length_zap do 
			  _dots := _dots + '.';
            writeln(itm[_j].n, ' ', itm[_j].name, ' ', _dots, ' ', itm[_j].time);
          end;
        end; 
        Draw_Active;    
        exit;
      end;
  end;
end;

// Процедура ввода новой задачи
procedure Enter_Task;
begin
// Останавливаем таймер:
  t.Stop;
  play := false;
  Draw_Active;
  // Далее:  
  IO_Print('Введите новую задачу: ');
  ReadLn(NewTask);
  if Check_New_Task(NewTask) = true then 
  begin
    Add_Task(NewTask);
    Show_Items;
    Draw_Top;
    Brush_Sel;
    Total_Time;
  end;
  // Выводим отработанное время:
  prnt(9, 1, top_col, white, ful_time_str.hr + ':' + ful_time_str.min); 
  // Выводим основной таймер:
  prnt(main_time_x, 1, top_col, white, main_time_str.hr+':'+main_time_str.min+':'+main_time_str.sec); 
end;

// Процедура удаления задачи
procedure Delete_Task;
var 
  DelTask : String[2];
  n : real;
  _i, code : integer;
begin
  // Если пунктов нет, то и работы нет:
  If LastItem = 0 then 
    exit;
  // Останавливаем таймер:
  t.Stop;
  play := false;
  Draw_Active;
  // Далее:  
  IO_Print('Введите номер задачи для удаления: ');
  ReadLn(DelTask);
  Val(DelTask, n, code); // Принимаем значение только с цифрами
  // Если удаляется последний пункт, то выделение снимается:  
  if LastItem = 1 then 
    ActiveItem := 0;
  // Удаление задачи:
  if (n > 0) and 
    (n <= LastItem) then
  begin
    for _i := round(n) to LastItem do
      with itm[_i] do
      begin  
        time := itm[_i + 1].time;
        name := itm[_i + 1].name;
        select := itm[_i + 1].select;
        run := itm[_i + 1].run;
      end;
    itm[LastItem].name := '';
    itm[LastItem].select := false;
    itm[LastItem].run := false
  end;
  clrscr;
  Show_Items;
  Draw_Top;
  Total_Time;
  // Рисуем выделение только тогда, когда удалённый пункт не последний
  if lastitem <> 0 then 
    Brush_Sel; 
  // Выводим отработанное время:
  prnt(9, 1, top_col, white, ful_time_str.hr + ':' + ful_time_str.min);
  // Выводим основной таймер:
  prnt(main_time_x, 1, top_Col, white, main_time_str.min + ':' + main_time_str.sec);
end;

// Процедура перемещения задач:
procedure Replace_Task;
var
  a, b : String[2];
  _a, _b : real;
  _i, code : integer;
begin
  // Если пунктов нет, то и работы нет:
  If LastItem = 0 then 
    exit;
  // Останавливаем таймер:
  t.Stop;
  play := false;
  Draw_Active;
  // Далее:  
  IO_Print('Введите задачи, которые нужно поменять местами: ');
  ReadLn(a, b);
  Val(a, _a, code); // Принимаем значение только с цифрами
  Val(b, _b, code);  
  if (_a > 0) 
    and (_a <= LastItem + 1) 
	and (_b > 0) 
	and (_b <= LastItem + 1) then
  begin
    // Перемещение пункта _а в резервный пункт:
    itm[max_tasks + 1].time := itm[round(_a)].time;
    itm[max_tasks + 1].name := itm[round(_a)].name;
    itm[max_tasks + 1].select := itm[round(_a)].select;
    itm[max_tasks + 1].run := itm[round(_a)].run;
    // Перемещение пункта _b в пункт _a:
    itm[round(_a)].time := itm[round(_b)].time;
    itm[round(_a)].name := itm[round(_b)].name;
    itm[round(_a)].select := itm[round(_b)].select;
    itm[round(_a)].run := itm[round(_b)].run;
    // Перемещение резервного пункта в пункт _b:
    itm[round(_b)].time := itm[max_tasks + 1].time;
    itm[round(_b)].name := itm[max_tasks + 1].name;
    itm[round(_b)].select := itm[max_tasks + 1].select;
    itm[round(_b)].run := itm[max_tasks + 1].run;
    // *** Очистка резервного пункта нужна? ***
    clrscr;
    Show_Items;
    Draw_Top;
    Brush_Sel;  
    Total_Time;
    // Выводим отработанное время:
    prnt(9, 1, top_col, white, ful_time_str.hr + ':' + ful_time_str.min);
    // Выводим основной таймер:
    prnt(main_time_x, 1, top_col, white, main_time_str.min + ':' + main_time_str.sec);
  end;
end;

// Процедура переименования задачи:
procedure Rename_Task;
var
  n : String[2];
  _n : real;
  code : integer;
begin
  // Если пунктов нет, то и работы нет:
  If LastItem = 0 then 
    exit;
  // Останавливаем таймер:
  t.Stop;
  play := false;
  Draw_Active;
  // Далее:  
  IO_Print('Введите номер задачи, которую надо изменить: ');  
  ReadLn(n);
  Val(n, _n, code); // Принимаем значение только с цифрами
  if (_n > 0) 
    and (_n <= LastItem) then
  begin
    IO_Print('Введите новую задачу и время: ');  
    ReadLn(NewTask);
    if Check_New_Task(NewTask) = true then 
    begin
      itm[round(_n)].name := Copy(NewTask, 1, LastPos(' -- ', NewTask)-1); 
      itm[round(_n)].time := StrToInt(Copy(NewTask, LastPos(' -- ', NewTask)+4, Length(NewTask) - (Length(itm[round(_n)].name)+3))); 
    end;
  end;
  clrscr;
  Show_Items;
  Draw_Top;
  Brush_Sel;
  Total_Time;
  // Выводим отработанное время:
  prnt(9, 1, top_col, white, ful_time_str.hr + ':' + ful_time_str.min);
  // Выводим основной таймер:
  prnt(main_time_x, 1, top_col, white, main_time_str.min + ':' + main_time_str.sec);
end;

procedure Up;
begin
  // Если пунктов нет, то и перемещения нет:
  If LastItem = 0 then 
    exit;
  // 1. Если выделенный пунктов нет, то выделяем первый снизу:
  if SelItem = 0 then 
    SelItem := LastItem + 1;
  // 2. Если выделен верхний пункт, то переходим на нижний:
  if SelItem = 1 then 
    SelItem := LastItem + 1;
  // 3. Вдругих случаях - поднимаем выделение вверх:
  SelItem := SelItem - 1;
  // ПОКРАСКА СТРОКИ:
  // 1. Перекрашиваем все пункты в стандартный цвет:
  Show_Items;
  // 2. Красим выделенный пункт:
  Brush_Sel;
end;

procedure Down;
begin
  // Если пунктов нет, то и перемещения нет:
  If LastItem = 0 then 
    exit;
  // 1. Если выделенный пунктов нет, то выделяем первый сверху:
  if SelItem = 0 then 
    SelItem := 0;
  // 2. Если выделен нижний пункт, то переходим на первый:
  if SelItem = LastItem then 
    SelItem := 0;
  // 3. Вдругих случаях - опускаем выделение вверх:
  SelItem := SelItem + 1;
  // ПОКРАСКА СТРОКИ:
  // 1. Перекрашиваем все пункты в стандартный цвет:
  Show_Items;
  // 2. Красим выделенный пункт:
  Brush_Sel;
end;

// Процедура при нажатии "Энтера".
procedure Enter;
begin
  // Если пунктов нет, то и работы нет:
  If LastItem = 0 then 
    exit;
  // Если стрелочка на выделенном пункте и таймер выключен, то запускаем таймер. Иначе - отключаем:
  if (ActiveItem = SelItem - 1) 
    and (play = false) then 
    begin
      WorkItem := SelItem;
      play := true;
      t.Start;
    end 
	else 
    begin 
      play := false; 
      t.Stop;
    end;
  // Если не продолжаешь работать на старом пункте, а запускаешь новый, то счётчик обнуляется:  
  if SelItem <> WorkItem then 
    Tmr_Clr; // tmr := 0;
  // Перетаскиваем стрелочку на выделенный пункт:
  if SelItem <> 0 then
    ActiveItem := SelItem - 1;
  // Перерисовываем экран:  
  Show_Items;
  // Оставляем выделение при нажатии "Энтера":
  Brush_Sel;  
end;

// Процедура работы таймера:
procedure TimerProc;
begin
  // Считаем вообще отработанное время:  
  ful_time.sec := ful_time.sec + 1;
  if ful_time.sec = 60 then
  begin
    ful_time.sec := 0;
    ful_time.min := ful_time.min + 1;
  end;
  if ful_time.min = 60 then
  begin
    ful_time.min := 0;
    ful_time.hr := ful_time.hr + 1;
  end;
  if ful_time.sec < 10 then 
    ful_time_str.sec := '0' + inttostr(ful_time.sec) 
  else 
	ful_time_str.sec := inttostr(ful_time.sec);
  if ful_time.min < 10 then 
    ful_time_str.min := '0' + inttostr(ful_time.min) 
  else 
	ful_time_str.min := inttostr(ful_time.min);
  if ful_time.hr < 10 then 
    ful_time_str.hr := '0' + inttostr(ful_time.hr) 
  else 
	ful_time_str.hr := inttostr(ful_time.hr);
  // И выводим его:
  prnt(9, 1, top_col, white, ful_time_str.hr + ':' + ful_time_str.min);
  // Основной счётчик:
  tmr := tmr + 1;
  // Считаем основной счётчик (секунды также могут записываться из tmr):
  main_time.sec := main_time.sec + 1;
  // Считаем отработанное время:  
  if main_time.sec = 60 then
  begin
    main_time.sec := 0;
    main_time.min := main_time.min + 1;
  end;
  if main_time.min = 60 then
  begin
    main_time.min := 0;
    main_time.hr := main_time.hr + 1;
  end;
  if main_time.sec < 10 then 
    main_time_str.sec := '0' + inttostr(main_time.sec) else 
	main_time_str.sec := inttostr(main_time.sec);
  if main_time.min < 10 then 
    main_time_str.min := '0' + inttostr(main_time.min) else 
	main_time_str.min := inttostr(main_time.min);
  if main_time.hr < 10 then 
    main_time_str.hr := '0' + inttostr(main_time.hr) else 
	main_time_str.hr := inttostr(main_time.hr);
  // Выводим отработанное время:
  // 1. Очищаем место под имя (*** надо ли? ***):
  prnt(main_time_x, 1, top_col, white, main_time_str.hr + ':' + main_time_str.min + ':' + main_time_str.sec + '                                             ');
  // 2. Выводим имя (*** подумать, надо ли ***):
  prnt(main_time_x, 1, top_col, white, main_time_str.hr + ':' + main_time_str.min + ':' + main_time_str.sec + ' - ' + itm[selitem].name);
  // По выполнении - переход на следующий пункт:
  if (main_time.min+(main_time.hr*60) div 60 = itm[SelItem].time) then // первой части равен tmr
  begin
    Tmr_Clr;
    ActiveItem := ActiveItem + 1;
    SelItem := SelItem + 1;
    // Перерисовываем пункты и раскрашиваем выделенный:
    Show_Items;
    Brush_Sel;
  end;
  // Если выполнялся последний пункт: // *** Почему-то не фурычит, приходится люто колхозить, закрашивать, но всё равно артефакт вылезает
  if ActiveItem = LastItem then 
  begin
    Tmr_Clr;
    ActiveItem := LAstItem;
    SelItem := LAstItem;
    // Перерисовываем пункты и раскрашиваем выделенный:
    //  Show_Items;
    Brush_Sel;
    // Draw_Active;
    play := false;
    gotoxy(stroka_length + 9, LastItem + 2); 
	write(' '); // Это надо в цикл по всему списку?
    gotoxy(stroka_length + 9, ActiveItem + 2); 
	write(':');
    gotoxy(1, LastItem + 3); 
	write('                                                                                ');
    // Нули в табло таймера:
    prnt(main_time_x, 1, top_col, white, '00:00:00');
    t.Stop;  
  end;
  // Тут поле ввода во время работы таймера:
  gotoxy(18, con_height - 1);
end;

// ТЕЛО ПРОГРАММЫ:
begin
  clrscr;
  // Создаём таймер:
  t := new Timer(50, TimerProc); // 1000
  // Обнуляем общее количество отработанного времени и выводим его:
  ful_time.hr := 0;
  ful_time.min := 0;
  ful_time.sec := 0;
  ful_time_str.hr := '00';
  ful_time_str.min := '00';
  ful_time_str.sec := '00';
  // Обнуляем основной счётчик и выводим его:
  Tmr_Clr;
  // Обнуляем выделенный пункт:
  SelItem := 0;
  // Стрелочка в нерабочем состоянии:
  play := false;
  // Заполняем пункты itm:
  for i := 1 to max_tasks + 1 do   // +1 - Резервируем 21 пункт как пустой
    with itm[i] do
    begin  
      n := i;  
      time := 0;
      name := '';
      select := false;
      run := false;
    end;
  // Считываем задачи из файла:
  Open_Tasks_File;
  // Рисуем шапку:
  Draw_Top;
  // Активность устанавливаем на первый пункт:
  if LastItem <> 0 then ActiveItem := 1;
  // Выводим пункты:
  Show_Items;
  // Выводим общее время:
  Total_Time;
  // Выводим количество отработанного времени:
  prnt(9, 1, top_col, white, '00:00');
  // Выводим основной счётчик:
  prnt(main_time_x, 1, top_col, white, '00:00:00');
  // Выделение устанавливаем на первый пункт:
  if LastItem <> 0 then 
  begin
    SelItem := 1;
    Brush_Sel;
  end;
  // Область ввода команд:
  repeat
    IO_Print('Введите команду: ');
    com := ReadKey;
    case LowCase(com) of
      'a', 'ф' : Enter_Task;
      'd', 'в' : Delete_Task;
      'p', 'з' : Replace_Task;
      'n', 'т' : Rename_Task;
      #38 : Up;
      #40 : Down;
      #13 : Enter;
      // #32 - Пробел
      // Enter - #13
    end;
  until (LowCase(com) = 'q') 
    or (LowCase(com) = 'й');
  // Завершение работы:  
  IO_Print('Всего хорошего! ');
  // Сохраняем задачи в файл:
  Save_Tasks_File;
  // Останавливаем таймер:
  t.Stop; 
end.
