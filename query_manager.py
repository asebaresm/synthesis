#RUN:
#  $ python query_manager.py MQL_input MQL_output
import os
import sys
import csv
import signal
import time
import datetime
import subprocess
import tflearn
import shutil
import itertools
import numpy as np
from subprocess import call
from watchdog.observers import Observer  
from watchdog.events import PatternMatchingEventHandler  
from indicators import *
from billWilliams import *

#parche
from fractales_lib import fractales
from investor_parser_lib import investor_parser
from trim_file15m_lib import trim_file15m

MODELO = None

class MyHandler(PatternMatchingEventHandler):
    patterns = ["*.gopy"]

    #event tienes los siguientes atributos y valores:
    """
    event.event_type gives:
        'modified' | 'created' | 'moved' | 'deleted'
    event.is_directory gives:
        True | False
    event.src_path gives:
        path/to/observed/file
    """
    def process(self, event):
        # the file will be processed there
        print('\n')
        print (event.src_path, event.event_type, datetime.datetime.now().time())  # print now only for debug
        
        query_path = event.src_path.split('.')[0] + ".m.query"
        if not os.path.exists(query_path):
            print("\nERR GRAVE: Se ha lanzado un \".m.gopy\" sin una query asociada en la ruta de input. Saliendo.")
            sys.exit(1)

        outDirCleanup(query_path)
        processQuery(query_path)

    def on_created(self, event):
        self.process(event)

#    def on_modified(self, event):
#        self.process(event)

#USO (provisional, solo para pruebas):
#1 - Modificar linea final a:
#       if __name__ == '__main__':
#            generateLast3()
#2 - $ python query_manager.py
#3 - Se genera el archivo 'LAST3.query' con los 3 últimos valores (15m) del modelo
#4 - 
def generateLast3():
    dirlist = ["test_processing/15m.data", "test_processing/30m.data", "test_processing/45m.data"]
    
    w = open('LAST3.query', 'w')

    for directory in dirlist:
        test_processingCleanup()

        investor_parser(directory)
        fractales('test_processing/PARSED.csv')
        test_as_nlist = ''
        with open('test_processing/fractal-PARSED.csv') as f:
            test = csv.reader(f)
            test_as_nlist = list(test)
        chain = itertools.chain(*test_as_nlist)
        flattened = list(chain)
        final_test = flattened[1:]
        #trim de dimensiones (4+1 pops agent-investor.py + investor.py)
        final_test = final_test[5:]
        w.write(str(final_test))
    w.close()

def outDirCleanup(query_path):
    modelt_wext = query_path.split('\\')[-1]
    modeltype = modelt_wext.split('.')[0]
    args = sys.argv[1:]
    output_path=args[1]

    if os.path.exists(output_path + '/' + modeltype + '.m.answer'):
        os.remove(output_path + '/' + modeltype + '.m.answer')

    if os.path.exists(output_path + '/' + modeltype + '.m.go'):
        os.remove(output_path + '/' + modeltype + '.m.go')

def test_processingCleanup():
    if os.path.exists('test_processing/fractal-PARSED.csv'):
        os.remove('test_processing/fractal-PARSED.csv')
    if os.path.exists('test_processing/PARSED.csv'):
        os.remove('test_processing/PARSED.csv')
    if os.path.exists('test_processing/QUERY.csv'):
        os.remove('test_processing/QUERY.csv')

def processQuery(query_path):
    content =""
    with open(query_path, 'r') as content_file:
        content = content_file.read()

    #eliminar query y fichero-semaforo
    os.remove(query_path)
    os.remove(query_path.split('.')[0] + ".m.gopy")

    print(query_path + ' leida y se ha eliminado. ' + str(datetime.datetime.now().time()))
    args = sys.argv[1:]

    #para cargar el modelo apropiado -> contenido en 'modeltype'
    modelt_wext = query_path.split('\\')[-1]
    modeltype = modelt_wext.split('.')[0]
    
    #path de retorno a MQL
    #MQL output
    if not os.path.exists(args[1]):
        os.makedirs(args[1])
    output_path=args[1]

    #path donde se procesa la query
    #if not os.path.exists('test_processing'):
    #    os.makedirs('test_processing')

    #eliminar ficheros intermedios de la query anterior, incluida raiz
    if os.path.exists('test_processing'):
        shutil.rmtree('test_processing')
    os.makedirs('test_processing')

    processf = 'test_processing/QUERY.csv' #ruta donde va la query en forma de csv a procesarse

    w = open(processf, 'w')
    w.write(content)
    w.close()

    # (...)

    #Problemas, nuevo enfoque:
    #trim_file15m('test_processing/QUERY.csv')
    #investor_parser('test_processing/TRIMMED.csv')
    investor_parser('test_processing/QUERY.csv')
    fractales('test_processing/PARSED.csv')
    to_predict(modeltype, output_path)
    #print ('modeltype is: ' + modeltype)

def to_predict(modeltype, MQL_outpath):
    print ('model is: ' + modeltype)

    net = tflearn.input_data(shape=[None, 4, 22])
    net = tflearn.lstm(net, 128, activation='linear', return_seq=True, dropout=0.8)
    net = tflearn.lstm(net, 128, activation='linear', return_seq=True, dropout=0.8)
    net = tflearn.lstm(net, 128, activation='linear', return_seq=True, dropout=0.8)
    net = tflearn.lstm(net, 128, activation='linear', return_seq=True, dropout=0.8)
    net = tflearn.lstm(net, 128, activation='linear', return_seq=False, dropout=0.8)
    net = tflearn.fully_connected(net, 3, activation='linear')
    net = tflearn.regression(net, optimizer='SGD',
                             loss='softmax_categorical_crossentropy', name="output1")
    model = tflearn.DNN(net, tensorboard_verbose=2)

    test_as_nlist = ''
    with open('test_processing/fractal-PARSED.csv') as f:
        test = csv.reader(f)
        test_as_nlist = list(test)

    #En este punto hay que:
    #   - Cargar el modelo a partir de su nombre(AUDJPY, EURBGP, etc) contenido en 'modeltype'
    #   - Hacer la prediccion y guardarla en predict_val
    global MODELO
    if MODELO is None:
        model.load('.\\models\\' + modeltype + '\\' + modeltype, weights_only=True)
        MODELO = model
    else:
        print ('Model already loaded from previous query, continue.')

    chain = itertools.chain(*test_as_nlist)
    flattened = list(chain)
    final_test = flattened[1:]
    #trim de dimensiones (4+1 pops agent-investor.py + investor.py)
    final_test = final_test[5:]
    print ('test is:\n' + str(final_test))
    
    #componer el test de 4 (15,30,45,00) para el predict
    last4 = np.empty((1,4,22))
    
    #last3 = ''
    #with open('LAST3.query', 'r') as f:
    #    last3 = f.readlines()
    
    #Se espera que en 'LAST3.query' se vayan almacenando los 3 ultimos test que se realicen del bot.
    #Provisionalmente son 3 fijos tomados de los datos de Forex (EURGBP.query)
    fl = open('LAST3.query')
    csv_f = csv.reader(fl)

    i = 0
    for row in csv_f:
        last4[0][i] = row
        i += 1

    last4[0][3] = final_test

    print ('WHOLE TEST IS: '+ str(last4))
    prediction = MODELO.predict(last4)
    print ('PREDICTION IS: ' + str(prediction))

    predict_val = 1

    #Fichero con la prediccion a MQL
    w = open(MQL_outpath + '/' + modeltype + '.m.answer', 'w')
    if predict_val == -1:   #Sell
       w.write('S')
    elif predict_val == 0:  #Hold
        w.write('H')
    else:
        w.write('B')    #Buy
    w.close()

    #señal de lectura lista a MQL:
    w = open(MQL_outpath + '/' + modeltype + '.m.go', 'w')
    w.close()

    print('Query processing done. ' + str(datetime.datetime.now().time() ))

def main():
    args = sys.argv[1:]

    #Handler para version no-daemon
    #signal.signal(signal.SIGINT, signal_handler)
    observer = Observer()
    #path donde va a escuchar el listener va en args[0]
    observer.schedule(MyHandler(), path=args[0] if args else '.')
    observer.start()
    print ('Observer started...')
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print ('\nCtrl + C - killing watchdog...')
        observer.stop()

    observer.join()

#def signal_handler(signal, frame):
#    print 'You pressed Ctrl+C!'
#    sys.exit(0)

#
if __name__ == '__main__':
    main()

