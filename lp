import fileinput
import itertools
import os
import queue
import struct
import sys
import threading
import time
import warnings
from datetime import datetime
from time import sleep

import keyboard
import numpy as np
import pandas as pd
from PyQt5.QtCore import Qt, QDateTime, QTimer, QPoint, QProcess
from PyQt5.QtGui import QFont
from PyQt5.QtGui import QPixmap
from PyQt5.QtWidgets import QAbstractSpinBox, QSlider
from PyQt5.QtWidgets import QApplication, QMessageBox
from PyQt5.QtWidgets import QMainWindow, QHBoxLayout, QTextEdit, QSizePolicy, QGraphicsOpacityEffect, QPushButton, \
    QCheckBox, QGridLayout, QInputDialog, QComboBox
from PyQt5.QtWidgets import QWidget, QLabel, QDoubleSpinBox, QVBoxLayout
from numba import prange
from ping3 import ping
from pyModbusTCP.client import ModbusClient
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

warnings.simplefilter(action='ignore', category=FutureWarning)


def warning_window(sometext):
    app = QApplication(sys.argv)
    win = QMessageBox()
    win.setWindowFlags(Qt.FramelessWindowHint)
    win.setWindowTitle("Error")
    win.setText(str(sometext))
    win.setIcon(QMessageBox.Warning)
    win.setFont(QFont("Arial", 23))
    win.show()
    sys.exit(app.exec_())


IZDELIE = ''
IMG = 'BG.png'
setting = "setting1.txt"
ips = {}
sensor_size = 14
hidename = 0
Vrema = "%H_%M_%S__%d-%m-%y"
with open(setting) as f:
    for indx,line in enumerate(f):
        try:
            if any(
                    var in line for var in (
                            'ips',
                            'IZDELIE',
                            'sensor_size',
                            'hidename')):
                exec(line)
        except SyntaxError as e:
            warning_window(f'Синтаксическая ошибка!\n{indx} строка\n\n{line} ')

new_list_of_dict_values = [list(range(1, chs + 1)) if type(chs) == int else chs for i, chs in
                           enumerate(list(ips.values()))]

pings = [ip for ip in ips.keys() if not ping(ip)]
if pings:
    warning_window(f"{pings} \n lost connection")


def long_function(q):
    while True:
        data = []
        try:
            # sleep(1)
            for key, value in ips.items():
                index = list(ips.keys()).index(key)
                client = ModbusClient(host=key, port=502, unit_id=1, auto_open=True)
                listd = []
                sleep(1 / 18)
                for ch in prange(
                        (new_list_of_dict_values[index][0] - 1) * 2, (new_list_of_dict_values[index][-1]) * 2, 2):
                    try:
                        response = client.read_input_registers(ch, reg_nb=2)
                        decoder = BinaryPayloadDecoder.fromRegisters(
                            response, Endian.Big, wordorder=Endian.Little).decode_32bit_float()
                        listd.append(decoder)
                    except Exception as error:
                        print(key)
                        print(ch)
                        print(error)
                data.append(listd)
            q.put_nowait(data)
        except Exception as error:
            data.append(0)
            print(error, 'cicle', )
            print(time.strftime("%d/%m/%y %H:%M:%S"))
            t1.start()


def t1live():
    if t1.is_alive():
        return qe.get()

qe = queue.Queue()
t1 = threading.Thread(target=long_function, args=[qe])
t1.start()


class Damper(QWidget):
    def __init__(
            self,
            namez='ЗУ',
            side='G',
            chr_open=0,
            chr_close=1,
            chdv_open=0,
            chdv_close=1,
            reg=1,
            parent=None):
        super(Damper, self).__init__(parent)
        self.widgetA = None
        self.namez = namez
        self.side = side
        self.widget = QWidget(self)
        self.layout = QGridLayout()
        self.lab = QPushButton(f'{self.namez}')
        self.lab.setStyleSheet(
            'font:bold;border-radius: 10px;border: 1px solid black;margin-bottom: 0;text-align: top;')
        self.widget.setLayout(self.layout)
        self.widget.setStyleSheet(
            ".QWidget {border: 1px solid black;border-radius: 25;background-color: rgb(255, 255, 255);}")
        self.btnUpdate1 = QPushButton()
        self.btnUpdate1.pressed.connect(self.tzRon)
        self.btnUpdate1.released.connect(self.tzRoff)

        self.btnUpdate1.setStyleSheet("""
                QPushButton{
                background-color: #A61300;
                border-bottom-left-radius:10px;
                border-top-right-radius:10px;
                margin-top: 13px;}
                }
               QPushButton:pressed { background-color: #FF2800 }
                """)
        self.btnUpdate2 = QPushButton()
        self.btnUpdate2.pressed.connect(self.tzGon)
        self.btnUpdate2.released.connect(self.tzGoff)
        self.btnUpdate2.setStyleSheet("""
                        QPushButton{
                        background-color: #007C21;
                        border-top-left-radius:10px;
                        border-bottom-right-radius:10px;
                        margin-top: 13px;
                        }
                        QPushButton:pressed { background-color: #64DF85 }
                        """)
        self.size0 = 0
        self.sizebtn = (50 + self.size0, 35 + self.size0)
        self.layout.setVerticalSpacing(0)
        self.layout.setHorizontalSpacing(0)
        self.btnUpdate1.setFixedSize(self.sizebtn[0], self.sizebtn[1])
        self.btnUpdate2.setFixedSize(self.sizebtn[0], self.sizebtn[1])
        self.widget.setFixedSize(120 + self.size0 * 2, 60 + self.size0 * 2)
        self.lab.setFixedSize(100 + self.size0, 25 + self.size0)
        self.lab.setStyleSheet("{ text-align: center; }")
        self.layout.addWidget(self.lab, 0, 0, 1, 2)
        self.layout.addWidget(self.btnUpdate1, 1, 0, 4, 1)
        self.layout.addWidget(self.btnUpdate2, 1, 1, 4, 1)
        self.chkb = QCheckBox()
        self.chkb.setStyleSheet(
            "QCheckBox::indicator { width: 10; height: 10;}")
        self.layout.addWidget(self.chkb, 0, 0, 3, 1)

        if self.side == 'V':
            self.btnUpdate1.setStyleSheet("""QPushButton{
                background-color: #A61300;
                border-bottom-left-radius:10px;
                border-top-right-radius:10px;
                margin-top: 0px;}
                }
               QPushButton:pressed { background-color: #FF2800 }
                """)
            self.btnUpdate2.setStyleSheet("""
                                   QPushButton{
                                   background-color: #007C21;
                                   border-top-left-radius:10px;
                                   border-bottom-right-radius:10px;
                                   margin-top: 0px;
                                   }
                                   QPushButton:pressed { background-color: #64DF85 }
                                   """)
            self.widget.setFixedSize(65 + self.size0 * 2, 110 + self.size0 * 2)
            self.sizebtn = (25 + self.size0, 50 + self.size0)
            self.btnUpdate1.setFixedSize(self.sizebtn[0], self.sizebtn[1])
            self.btnUpdate2.setFixedSize(self.sizebtn[0], self.sizebtn[1])
            self.layout.setHorizontalSpacing(1)
            self.lab.setFixedSize(25 + self.size0, 95 + self.size0)
            self.layout.addWidget(self.lab, 0, 1, 2, 1)
            self.layout.addWidget(self.btnUpdate1, 1, 0, 1, 1)
            self.layout.addWidget(self.btnUpdate2, 0, 0, 1, 1)

        self.show()
        self.reg = reg - 1
        self.ip = list(ips)[self.reg]
        self.c = (
            ModbusClient(
                host=self.ip,
                port=502,
                unit_id=1,
                auto_open=True))
        self.chdv_open = chdv_open - 1
        self.chdv_close = chdv_close - 1
        self.chr_open = chr_open - 1
        self.chr_close = chr_close - 1
        self.lab.clicked.connect(self.info)
        self.moveon = False
        self.chkb.stateChanged.connect(self.automatvisibl)

    def automatvisibl(self):
        if self.chkb.isChecked():
            try:
                self.widgetA.show()
            except Exception:
                self.widgetA = QWidget(dlgMain)
                self.widgetA.setWindowFlags(Qt.FramelessWindowHint)
                self.widgetA.setGeometry(
                    self.x(), int(
                        self.y() + self.size().height() / 3), 100, 160)
                if self.side == 'V':
                    self.widgetA.setGeometry(
                        int(self.x() + self.size().width() / 3), self.y(), 100, 160)

                self.widgetA.layout = QVBoxLayout()
                self.widgetA.setLayout(self.widgetA.layout)

                self.comboA = QComboBox()
                self.comboA.addItems(
                    [f'{i.name}:   {i.ch}/{i.reg}' for i in dlgMain.ourch])

                self.ustA = QDoubleSpinBox()
                self.ustA.setDecimals(4)
                self.ustA.setStepType(QAbstractSpinBox.AdaptiveDecimalStepType)

                self.dopskA = QDoubleSpinBox()
                self.dopskA.setStepType(
                    QAbstractSpinBox.AdaptiveDecimalStepType)
                self.dopskA.setDecimals(4)
                self.dopskA.setValue(0.5)
                self.dopskA.setMinimum(0.01)

                self.timesleep = QDoubleSpinBox()
                self.timesleep.setStepType(
                    QAbstractSpinBox.AdaptiveDecimalStepType)
                self.timesleep.setDecimals(4)
                self.timesleep.setValue(1)
                self.timesleep.setMinimum(0.01)

                self.timesleepaft = QDoubleSpinBox()
                self.timesleepaft.setStepType(
                    QAbstractSpinBox.AdaptiveDecimalStepType)
                self.timesleepaft.setDecimals(4)
                self.timesleepaft.setMinimum(1)
                self.timesleepaft.setValue(4)

                self.limit = QDoubleSpinBox()
                self.limit.setStepType(
                    QAbstractSpinBox.AdaptiveDecimalStepType)
                self.limit.setDecimals(4)
                self.limit.setValue(12)

                self.chkbA = QCheckBox()
                self.chkbA.stateChanged.connect(self.automatwork)

                self.widgetA.layout.addWidget(self.comboA)
                self.widgetA.layout.addWidget(self.ustA)
                self.widgetA.layout.addWidget(self.dopskA)
                self.widgetA.layout.addWidget(self.timesleep)
                self.widgetA.layout.addWidget(self.timesleepaft)
                self.widgetA.layout.addWidget(self.limit)
                self.widgetA.layout.addWidget(self.chkbA)
                self.widgetA.show()
        else:
            self.widgetA.hide()

    def datchik(self):
        for i in dlgMain.ourch:
            if self.comboA.currentText()[
               :self.comboA.currentText().find(':')] in i.name:
                return i

    def automatwork(self):
        if self.chkbA.isChecked():
            self.condition = False
            threading.Thread(target=self.p_auto).start()
        else:
            self.condition = True

    def low(self):
        for step in range(1, 10):
            step_value = self.ustA.value() / 2 ** step
            if self.dadata < step_value:
                return self.timesleep.value() / 2 ** (step - 1)
        return self.timesleep.value()

    def up(self):
        for step in range(10, 0, -1):
            threshold = self.ustA.value() * (1 - 1 / 2 ** step)
            if self.dadata >= threshold:
                return self.timesleep.value() / 2 ** step
        return self.timesleep.value()

    def p_auto(self, q):
        try:
            while self.condition is False:
                self.da = self.datchik()
                self.diapozon = np.arange(
                    self.ustA.value() -
                    self.dopskA.value(),
                    self.ustA.value() +
                    self.dopskA.value(),
                    0.001,
                    dtype=float)
                self.diapozon = [round(n, 3) for n in self.diapozon]
                self.dadata = float("{:.3f}".format(
                    t1live()[self.da.reg][new_list_of_dict_values[self.da.reg].index(self.da.ch)]))
                if self.dadata < self.diapozon[0] and self.dadata > 0:
                    self.tzGon()
                    sleep(self.low())
                    self.tzGoff()
                    sleep(self.timesleepaft.value())
                elif self.dadata > self.diapozon[-1]:
                    self.tzRon()
                    sleep(self.up())
                    self.tzRoff()
                    sleep(self.timesleepaft.value())
                elif self.dadata >= self.limit.value():
                    self.tzRon()
                    sleep(self.timesleepaft.value())
                    self.tzRoff()
                    sleep(self.timesleepaft.value())
                    continue
        except Exception:
            sleep(1)

    def update_dadata(self):
        self.da = self.datchik()
        self.set_diapozon()
        self.dadata = float("{:.3f}".format(
            t1live()[self.da.reg][new_list_of_dict_values[self.da.reg].index(self.da.ch)]))

    def set_diapozon(self):
        self.diapozon = np.arange(self.ustA.value() - self.dopskA.value(),
                                  self.ustA.value() + self.dopskA.value(),
                                  0.001, dtype=float)
        self.diapozon = [round(n, 3) for n in self.diapozon]

    def perform_action(self, action_function, sleep_function=None):
        action_function()
        if sleep_function:
            sleep(sleep_function())
        else:
            sleep(self.timesleepaft.value())
        action_function.off()

    def colorzaslonka(self):
        try:
            chdv_open = self.c.read_discrete_inputs(self.chdv_open, 1)[0]
            chdv_close = self.c.read_discrete_inputs(self.chdv_close, 1)[0]

            if chdv_open:
                color = '#00FF00'  # green
            elif chdv_close:
                color = '#FF0000'  # red
            else:
                color = '#FFFF00'  # yellow

            self.lab.setStyleSheet(
                f"""font:bold;border-radius: 10px;border: 1px solid black;
                                    margin-bottom: 0;background-color: {color};text-align: center;""")
            self.c.close()
        except Exception:
            pass

    def tzGon(self):
        threading.Thread(target=self.evt_btnUpdate_green_on).start()

    def tzGoff(self):
        threading.Thread(target=self.evt_btnUpdate_green_off).start()

    def tzRon(self):
        threading.Thread(target=self.evt_btnUpdate_red_on).start()

    def tzRoff(self):
        threading.Thread(target=self.evt_btnUpdate_red_off).start()

    def evt_btnUpdate_green_on(self):
        sleep(1 / 50)
        self.c.write_multiple_coils(self.chr_open, [1])
        self.lab.setStyleSheet(
            'font:bold;border-radius: 10px;border: 1px solid black;'
            'margin-bottom: 0;background-color: #2E8B57 ;text-align: center;')
        self.c.close()

    def evt_btnUpdate_green_off(self):
        sleep(1 / 50)
        self.c.write_multiple_coils(self.chr_open, [0])
        self.c.close()
        self.colorzaslonka()

    def evt_btnUpdate_red_on(self):
        sleep(1 / 50)
        self.c.write_multiple_coils(self.chr_close, [1])
        self.lab.setStyleSheet(
            'font:bold;border-radius: 10px;border: 1px solid black;'
            'margin-bottom: 0;background-color:#B22222 ;text-align: center;')
        self.c.close()

    def evt_btnUpdate_red_off(self):
        sleep(1 / 50)
        self.c.write_multiple_coils(self.chr_close, [0])
        self.c.close()
        self.colorzaslonka()

    def mousePressEvent(self, evt):
        if self.moveon:
            self.oldPos = evt.globalPos()

    def mouseMoveEvent(self, evt):
        if self.moveon:
            delta = QPoint(evt.globalPos() - self.oldPos)
            self.move(self.x() + delta.x(), self.y() + delta.y())
            self.oldPos = evt.globalPos()
            with fileinput.FileInput(setting, inplace=True,
                                     backup='.bak') as f:
                for line in f:
                    if self.namez in line and '<=>' not in line:
                        replacement_text = (
                                line[:line.rfind(' (')] + f' ({self.x()} {self.y()})\n')
                        print(line.replace(line, replacement_text), end='')
                    else:
                        print(line, end='')

    def info(self):
        self.w = AnotherWindow()  # ,chr_open=0, chr_close=1, chdv_open=0, chdv_close=1,
        self.w.label1.setText(f'name {self.namez}')
        self.w.label2.setText(
            f'chr_op {self.chr_open} ,chr_cl {self.chr_close} ')
        self.w.label3.setText(
            f'chdv_op {str(self.chdv_open)} ,chdv_cl {str(self.chdv_close)}')
        self.w.label4.setText(f'{self.pos()}')
        self.w.slider.valueChanged.connect(self.scaletext)
        self.wi = self.widget.width()
        self.he = self.widget.height()
        self.wi_lab = self.lab.width()
        self.he_lab = self.lab.height()
        self.wi_b1 = self.btnUpdate1.width()
        self.he_b1 = self.btnUpdate1.height()
        self.wi_b2 = self.btnUpdate2.width()
        self.he_b2 = self.btnUpdate2.height()
        self.w.show()

    def scaletext(self, value):
        custom_font = QFont()
        custom_font.setPointSize(7 + value // 2)
        self.setFixedSize(self.width() + value,
                          int(self.height() + value / 15))
        self.lab.setFont(custom_font)
        self.lab.setFixedSize(self.wi_lab + value, self.he_lab + value)
        self.widget.setFixedSize(self.wi + value * 2, self.he + value * 2)
        self.btnUpdate1.setFixedSize(
            int(self.wi_b1 + value / 2), int(self.he_b1 + value / 2))
        self.btnUpdate2.setFixedSize(
            int(self.wi_b2 + value / 2), int(self.he_b2 + value / 2))

    #   self.layout.setFixedSize(self.layout.height()+value,self.layout.width()+value)
    #        self.w.show()

    def __str__(self):
        return f"Name:{self.namez}"


class AnotherWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setFont(QFont("Arial", 12))

        self.layoutAW = QVBoxLayout()
        self.label1 = QLabel()
        self.label2 = QLabel()
        self.label3 = QLabel()
        self.label4 = QLabel()
        self.slider = QSlider()
        self.slider.setOrientation(Qt.Horizontal)
        self.slider.setRange(-100, 500)

        self.chk = QCheckBox()
        self.chklbl = QLabel()
        self.chklbl.setText('Name hide')
        self.layoutAW.addWidget(self.chk)
        self.layoutAW.addWidget(self.chklbl)

        self.layoutAW.addWidget(self.slider)
        self.layoutAW.addWidget(self.label1)
        self.layoutAW.addWidget(self.label2)
        self.layoutAW.addWidget(self.label3)
        self.layoutAW.addWidget(self.label4)

        self.setLayout(self.layoutAW)


class Sensor(QWidget):

    def __init__(
            self,
            name='♥',
            ch=1,
            clr='bl',
            side_name='l',
            reg=1,
            amendment=0.0,
            parent=None):
        super(Sensor, self).__init__(parent)
        self.setFixedSize(155, 70)
        self.name = name
        self.reg = reg - 1
        self.ch = ch
        self.amendment = amendment

        self.l1 = QPushButton(self.name)
        self.l1.setFont(QFont("Arial", 13))
        self.l1.setStyleSheet('border : 5;background: transparent;')
        self.l2 = QLabel('♣')

        self.l2.setFixedSize(101, 35)
        self.l2.setAlignment(Qt.AlignCenter)

        self.clr = clr
        self.ip = list(ips)[self.reg]
        self.c = (
            ModbusClient(
                host=self.ip,
                port=502,
                unit_id=1,
                auto_open=True))
        self.side_name = side_name
        self.layoutside(self.side_name)
        self.l2.setFont(QFont('Times', 18, weight=QFont.Bold))
        self.l2.setStyleSheet(self.bge())

        self.l1.clicked.connect(self.info)
        self.moveon = False
        self.scaletext(sensor_size)
        self.hidename(hidename)
        self.show()

    def bge(self):
        colors = {
            'si': '192,192,192',
            'wh': '255,255,255',
            'fu': '255,0,255',
            'pu': '238,130,238',
            're': '255,160,137',
            'ma': '128,0,0',
            'ye': '255,255,0',
            'ol': '128,128,0',
            'li': '0,255,0',
            'gr': '50,205,50',
            'aq': '0,255,255',
            'te': '0,128,128',
            'bl': '153,153,255',
            'na': '0,0,128'
        }

        if self.clr not in colors:
            return f'.QLabel{{background-color: rgb({self.clr});margin:1px;border:1px solid rgb(0,0,0);border-radius: 10px;}}'
        else:
            return f'.QLabel{{background-color: rgb({colors[self.clr]});margin:1px;border:1px solid rgb(0,0,0);border-radius: 10px;}}'

    def layoutside(self, side_name):
        if side_name.lower() == 'l':
            self.setGeometry(self.x(), self.y(), 150, 50)
            self.layout = QHBoxLayout(self)
            self.layout.addWidget(self.l1)
            self.layout.addWidget(self.l2)
        elif side_name.lower() == 't':
            self.setGeometry(self.x(), self.y(), 110, 80)
            self.layout = QVBoxLayout(self)
            self.layout.addWidget(self.l1)
            self.layout.addWidget(self.l2)
        elif side_name.lower() == 'r':
            self.setGeometry(self.x(), self.y(), 150, 50)
            self.layout = QHBoxLayout(self)
            self.layout.addWidget(self.l2)
            self.layout.addWidget(self.l1)
        elif side_name.lower() == 'b':
            self.setGeometry(self.x(), self.y(), 110, 80)
            self.layout = QVBoxLayout(self)
            self.layout.addWidget(self.l2)
            self.layout.addWidget(self.l1)

    def mousePressEvent(self, evt):
        if self.moveon:
            self.oldPos = evt.globalPos()

    def mouseMoveEvent(self, evt):
        if self.moveon:
            delta = evt.globalPos() - self.oldPos
            self.move(self.x() + delta.x(), self.y() + delta.y())
            self.oldPos = evt.globalPos()
            with open(setting, 'r') as f:
                lines = f.readlines()
            with open(setting, 'w') as f:
                for line in lines:
                    if self.name in line:
                        line = f'{line[:line.rfind(" (")]} ({self.x()} {self.y()})\n'
                    f.write(line)

    def poschange(self):
        self.layout.replaceWidget(self.l2, self.l1)
        self.show()

    def info(self):
        self.w = AnotherWindow()
        self.w.label1.setText(f'name {self.name}')
        self.w.label2.setText(f'ch {str(self.ch)}')
        self.w.label3.setText(f'registrator {str(self.reg)}')
        self.w.label4.setText(f'{self.pos()}')
        self.w.slider.valueChanged.connect(self.scaletext)
        self.w.chk.stateChanged.connect(self.hidename)
        self.w.show()

    def hidename(self, h):
        self.l1.hide() if h == 1 else self.l1.show()

    def scaletext(self, value):
        self.l2.setFont(QFont('Times', 14 + value, weight=QFont.Bold))
        self.l2.setFixedSize(100 + value * 5, 35 + value)
        self.setFixedSize(150 + value * 5, 70 + value * 2)

    def __str__(self):
        return f"{self.name}  ch {self.ch}  reg {self.reg + 1}"


class Translate(QPushButton):
    def __init__(self, z1, z2, zslp, parent=None):
        super(QPushButton, self).__init__(parent)
        self.setGeometry(parent.frameGeometry().width(
        ) - 200, parent.frameGeometry().height() - 500 + 20 * int(z1[-1]), 150, 30)
        self.setText(f' {z1}<=>{z2}')
        self.setFont(QFont("Fira Mono Bold", 13))
        self.setStyleSheet(
            "QPushButton {padding-top:7px;background-color : lightgreen;font:bold;border-radius: 10px;border: 1px solid black;margin-bottom: 0}"
            "QPushButton:pressed { background-color: red }")
        for i in zslp:
            if z1 in i.namez:
                self.z1 = i
            elif z2 in i.namez:
                self.z2 = i
        self.clicked.connect(self.tz)
        self.show()

    def tz(self):
        self.setEnabled(False)
        threading.Thread(
            target=self.rearrangement,
            args=[
                queue.Queue(),
                self.z1,
                self.z2]).start()

    def rearrangement(self, q, z1, z2):
        try:
            if z1.lab.styleSheet() == 'font:bold;border-radius: 10px;border: 1px solid black;margin-bottom: 0;background-color: #FF0000 ;text-align: center;':
                z1.tzGon()
                z2.tzRon()
                sleep(10)
                z1.tzGoff()
                z2.tzRoff()
            else:
                z2.tzGon()
                z1.tzRon()
                sleep(10)
                z2.tzGoff()
                z1.tzRoff()
            self.setEnabled(True)
        except Exception:
            warning_window('Проверьте концевики')


class Furnace(QSlider):
    def __init__(self, name='♥', ae=1, reg=1, parent=None):
        super(Furnace, self).__init__(parent)
        self.ae = ae - 1
        self.reg = reg - 1
        self.ip = list(ips)[self.reg]
        self.c = ModbusClient(
            host=self.ip,
            port=502,
            unit_id=1,
            auto_open=True)
        self.name = name
        self.setGeometry(parent.frameGeometry().width(
        ) - 200 + self.ae * 30, 50, 30, int(parent.frameGeometry().height() / 2))
        self.lb = QLabel(self.parent())
        self.lb.setFont(QFont('Arial', 10))
        self.lb.move(parent.frameGeometry().width() - 205 + self.ae * 30, 20)
        self.lb.show()
        self.setSingleStep(10)
        self.setRange(0, 20000)
        self.valueChanged.connect(lambda v: self.lb.setText(str(v / 1000)))
        self.sliderReleased.connect(self.tz)
        self.show()

    def tz(self):
        x = self.value()
        qez = queue.Queue()
        threading.Thread(target=self.signal, args=[qez, x]).start()

    def signal(self, q, value):
        f = value / 1000
        v = struct.unpack('>l', struct.pack('>f', f))[0]
        x = [(v & 0xffff), (v >> 16)]
        self.c.write_multiple_registers(self.ae, x)
        self.c.close()


class MainShem(QMainWindow):
    def __init__(self, parent=None):
        super(MainShem, self).__init__(parent)
        self.timestart = time.strftime(Vrema, time.localtime())
        self.showFullScreen()

        self.labelimg = QLabel(self)
        self.pixmap = QPixmap(IMG)
        self.labelimg.setPixmap(self.pixmap)
        self.labelimg.setScaledContents(True)
        self.labelimg.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Ignored)
        self.opacity_effect = QGraphicsOpacityEffect()
        self.opacity_effect.setOpacity(0.7)
        self.labelimg.setGraphicsEffect(self.opacity_effect)
        self.labelimg.setGeometry(200, 0, 1500, 1100)
        self.labelimg.show()

        self.ourch = self.read_file(setting)
        self.timermup = QTimer()
        self.timermup.timeout.connect(self.update_label)
        self.timermup.start()

        self.texttime = QWidget(self)
        self.texttime.setGeometry(0, 0, 600, 145)
        self.layout = QHBoxLayout()

        stl = "border: 2px solid black;border-radius: 10px;background-color:rgb(213,199,182)"
        self.Time = QLabel()
        self.Time.setGeometry(0, 0, 150, 100)
        self.Time.setFont(QFont('Arial', 30))
        self.Time.setStyleSheet(stl)
        self.layout.addWidget(self.Time)

        self.button = QPushButton('+')
        self.button.clicked.connect(self.addwidgt)
        self.button.setStyleSheet(stl)
        self.button.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Expanding)
        self.layout.addWidget(self.button)

        self.input = QTextEdit(self)
        self.input.setFont(QFont('Arial', 24))
        self.input.setStyleSheet(stl)
        self.layout.addWidget(self.input)
        self.input.textChanged.connect(self.text_changed)

        self.texttime.setLayout(self.layout)
        self.texttime.show()
        self.old_pos = None

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.showTime)
        self.timer.start()

        self.checkBox = QCheckBox()
        self.checkBox.stateChanged.connect(self.on_checkbox_changed)
        self.layout.addWidget(self.checkBox)

        self.timerfile = QTimer()
        self.timerfile.timeout.connect(self.do_things)
        self.timerfile.start(3600000)

        top_right_point = QApplication.desktop().availableGeometry().topRight()

        self.exit = QPushButton(self)
        self.exit.setGeometry(555, 555, 25, 25)
        self.exit.move(top_right_point / 1.015)
        self.exit.clicked.connect(self.closeEvent)
        self.exit.setText('X')
        self.exit.show()

        self.full = QPushButton(self)
        self.full.setGeometry(555, 555, 25, 25)
        self.full.move(top_right_point / 1.0275)
        self.full.clicked.connect(self.fullroll)
        self.full.setText('☻')
        self.full.show()

        self.roll = QPushButton(self)
        self.roll.setGeometry(555, 555, 25, 25)
        self.roll.move(top_right_point / 1.04)
        self.roll.clicked.connect(self.showMinimized)
        self.roll.setText('_')
        self.roll.show()
        self.sendol = dict(sorted(self.sendall().items()))
        keyboard.add_hotkey('PrtScn', self.print_screen)
    def text_changed(self):
        self.timerfile = QTimer()
        self.timerfile.timeout.connect(self.input.clearFocus)
        self.timerfile.start(36000)

    def closeEvent(self, event):
        reply = QMessageBox.question(self, 'Message',
                                     "Вы уверены, что хотите выйти?", QMessageBox.Yes |
                                     QMessageBox.No, QMessageBox.No)
        event.accept() if reply == QMessageBox.Yes else event.ignore()

    def fullroll(self):
        if self.isFullScreen():
            self.showNormal()
            self.showMaximized()
        else:
            self.showFullScreen()

    def do_things(self):
        self.timestart = time.strftime(Vrema, time.localtime())

    def on_checkbox_changed(self, value):
        for i in range(len(self.ourch)):
            self.ourch[i].moveon = Qt.CheckState(
                value) == Qt.CheckState.Checked
        for i in range(len(self.dampers_list)):
            self.dampers_list[i].moveon = Qt.CheckState(
                value) == Qt.CheckState.Checked
        if Qt.CheckState(value) == Qt.CheckState.Unchecked:
            for i in range(len(self.ourch)):
                self.ourch[i].moveon = False
            for i in range(len(self.dampers_list)):
                self.dampers_list[i].moveon = False
            self.close()
            QProcess.startDetached(sys.executable, sys.argv)

    def redakt(self, text):
        with fileinput.FileInput(setting, inplace=True,
                                 backup='.bak') as f:
            for line in f:
                if text[:text.find(' ')] + ' ' in line:
                    def find_2nd(string, substring):
                        return string.find(
                            substring, string.find(substring) + 8)

                    if '+' in text:
                        print(line[:find_2nd(line, ' ')] +
                              ' ' +
                              text[text.find('+') +
                                   1:] +
                              line[line.find(' ('):], end='')
                    elif '-' in text:
                        print(line[:find_2nd(line, ' ')] +
                              ' ' +
                              text[text.find('-'):] +
                              line[line.find(' ('):], end='')
                else:
                    print(line, end='')
            self.close()
            QProcess.startDetached(sys.executable, sys.argv)

    def addwidgt(self):
        inputdialog = QInputDialog()
        inputdialog.setInputMode(QInputDialog.TextInput)
        inputdialog.setWindowTitle('Input')
        inputdialog.setLabelText("""Образцы\n\n
        DT2 1 re r 1 (1280 97)\n
        name channale(1) color(re,bl,gr,pu) side(r,l,t,b) registrator(1) amendment(0.0) (x y)\n\n
                 или \n\n
        ZU1 V 0 1 0 1 1 (1393 364)\n
        name position(V,G) chR1 chR2 chDV1 chDV2 registrator (x y)\n""")
        inputdialog.setFont(QFont("Arial", 20))
        okpressed = inputdialog.exec_()
        text = inputdialog.textValue()
        chnamelist = []
        for i in prange(len(self.ourch)):
            chnamelist.append(self.ourch[i].name)
        if okpressed and text[:text.find(
                ' ')] in chnamelist and '+' in text or '-' in text:
            self.close()
            self.redakt(text)
        elif okpressed and text in chnamelist:
            self.close()
            with fileinput.FileInput(setting, inplace=True,
                                     backup='.bak') as f:
                for line in f:
                    if text + ' ' in line:
                        print(line.replace(line, ''), end='')
                    else:
                        print(line, end='')
                self.close()
                QProcess.startDetached(sys.executable, sys.argv)

        elif okpressed and text != '':
            with open(setting, 'a') as file:
                file.write(text + '\n')
            self.close()
            QProcess.startDetached(sys.executable, sys.argv)

    def showTime(self):
        self.Time.setText(
            QDateTime.currentDateTime().toString('d/M/yy\nhh:mm:ss'))

    def tofile(self, main_window_data):
        #      sleep(1 / 25)
        if os.path.isfile(
                IZDELIE +
                f'/report_{IZDELIE}/' +
                self.timestart +
                '.txt'):
            with open(IZDELIE + f'/report_{IZDELIE}/' + self.timestart + '.txt', 'a', newline='') as f:
                self.df = pd.DataFrame(
                    list(itertools.chain.from_iterable(main_window_data))).T
                self.df.insert(
                    0, 'Time', str(
                        datetime.now().strftime('%H:%M:%S.%f')[
                        :-3]))
                self.df.insert(
                    0, 'Data', str(
                        datetime.now().strftime('%d/%m/%y')))
                f.write(self.df.to_csv(sep=';', header=False, index=False))
        else:
            self.df = pd.DataFrame(
                list(itertools.chain.from_iterable(main_window_data))).T
            self.df = self.df.rename(columns=lambda x: x + 1)
            for i in self.df.columns:
                if i in self.sendol:
                    self.df = self.df.rename(columns={i: self.sendol[i]})
            self.df.insert(
                0, 'Time', str(
                    datetime.now().strftime('%H:%M:%S.%f')[
                    :-3]))
            self.df.insert(0, 'Data', str(datetime.now().strftime('%d/%m/%y')))
            os.makedirs(
                os.path.dirname(
                    IZDELIE +
                    f'/report_{IZDELIE}/'),
                exist_ok=True)
            with open(IZDELIE + f'/report_{IZDELIE}/' + self.timestart + '.txt', 'a', newline='') as f:
                f.write(self.df.to_csv(sep=';', header=True, index=False))

    def update_label(self):
        main_window_data = t1live()
        self.tofile(main_window_data)
        format_strings = {
            'DD': '{:.3f}',
            'DA': '{:.3f}',
            'dP': '{:.4f}',
            'G': '{:.0f}'
        }
        for i in self.ourch:
            try:
                x = main_window_data[i.reg][new_list_of_dict_values[i.reg].index(
                    i.ch)] + i.amendment
                if x == 'nan':
                    continue
                for substring, format_string in format_strings.items():
                    if substring in i.l1.text():
                        i.l2.setText(format_string.format(x))
                        break
                else:
                    i.l2.setText("{:.2f}".format(x))
            except ValueError:
                continue

    def sendall(self):
        dataname = {}
        for i in self.sensor_list:
            dataname[(i.ch + i.reg * 14)] = f'{i.name}_ch{i.ch}_r{i.reg}'
        #  dataname[(i.ch + sum(list(ips.values())[:i.reg]))] = f'{i.name}_ch{i.ch}_r{i.reg}'
        return dataname

    def read_file(self, setting):
        try:
            with open(setting) as file:
                self.sensor_list = []
                self.dampers_list = []
                self.translate_list = []
                for row in file:
                    setting = row[:row.find(' (')].split(' ')
                    move = row[row.find('(') + 1:row.find(')')].split()
                    if row == "\n" or any(
                            x in row for x in [
                                "#",
                                "ips",
                                "IZDELIE",
                                "sensor_size",
                                "hidename"]):
                        continue
                    elif any(x in row.lower() for x in ["zu", "ru"]) and '<=>' not in row:
                        damper = Damper(
                            setting[0], setting[1], int(
                                setting[2]), int(
                                setting[3]), int(
                                setting[4]), int(
                                setting[5]), int(
                                setting[6]), self)
                        damper.setGeometry(int(move[0]), int(move[1]), 150, 150)
                        self.dampers_list.append(damper)
                        continue
                    elif '<=>' in row:
                        self.translate_list.append(Translate(row[:row.find('<')], row[row.find(
                            '>') + 1:row.find('\n')], self.dampers_list, self))
                        [i.show() for i in self.translate_list]
                        continue
                    elif 'F' in row:
                        f = Furnace(
                            setting[0], int(
                                setting[1]), int(
                                setting[2]), self)
                        f.show()
                        continue
                    #elif any(x in row.lower() for x in ['da', 'dd', 'dt', 'dp', 'g']):
                    else:
                        sensor = Sensor(
                            setting[0], int(
                                setting[1]), setting[2], setting[3], int(
                                setting[4]), float(
                                setting[5]), self)
                        self.sensor_list.append(sensor)
                        if int(move[0]) > 0 and int(move[1]) > 0:
                            sensor.move(int(move[0]), int(move[1]))
                        else:
                            sensor.move(555, 555)

                return self.sensor_list
        except Exception as error:
            warning_window(f'{row}\n {error} непрвельный параметр')

    def print_screen(self):
        os.makedirs(os.path.dirname(IZDELIE + f'/screens_{IZDELIE}/'), exist_ok=True)
        self.grab().save(IZDELIE + f'/screens_{IZDELIE}/' + time.strftime(Vrema, time.localtime()) + ".jpg")


if __name__ == '__main__':
    try:
        app = QApplication(sys.argv)
        dlgMain = MainShem()
        dlgMain.show()
        sys.exit(app.exec_())
    except Exception as e:
        warning_window(e)
