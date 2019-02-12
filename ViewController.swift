//
//  ViewController.swift
//  ESP32 Laser Gate
//
//  Created by Zain Ahmed on 2/11/19.
//  Copyright © 2019 Zain Ahmed. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var TableView: UITableView!

    var list: [String] = []
    var tempList: [String] = []


    // ---------- BLUETOOTH ----------

    let serviceUUID = CBUUID(string: "0a197167-38cd-40a6-8e08-cc637b93b8ce")
    let characteristicUUID = CBUUID(string: "676e0287-815e-4f6f-b18a-64bcae972e90")

    var manager: CBCentralManager!
    var mainService: CBService! = nil
    var peripheral: CBPeripheral!
    var lapTimeCharacteristic: CBCharacteristic! = nil

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
            navBar.topItem?.title = "Searching..."
            print("scanning")
        } else {
            print("bluetooth not available")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "FSAE Gate Timer" {
            self.peripheral = peripheral
            central.connect(peripheral, options: nil)
            central.stopScan()
            print("gate timer found")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected")
        peripheral.delegate = self
        self.peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("time service discovered")

        guard let services = peripheral.services else{
            print("services not found")
            return
        }

        for service in services {
            if service.uuid == serviceUUID {
                print("found uuid")
                mainService = service
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }

    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("characteristics discovered")

        for characteristic in service.characteristics! {
            if characteristic.uuid == characteristicUUID {
                self.lapTimeCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: characteristic)
                navBar.topItem?.title = "Lap Times"
            }
        }
    }


    var hadZero = false
    // Every time the ESP32 notifies of new data, this func is fired
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let asciiString = String(data: characteristic.value!, encoding: String.Encoding.ascii)
        let num = Double(asciiString!)
        print(num as Any)

        if hadZero {
            list.removeAll()
            tempList.removeAll()
            hadZero = false
        }

        let numString = String(format: "%.2f", num!)

        if num != 0.00 {
            //        list.append(numString)
            tempList.append(numString)
            //        TableView.reloadData()
        }

        if num == 0.00 {
            hadZero = true
            list = tempList
            TableView.reloadData()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        central.scanForPeripherals(withServices: nil, options: nil)
        print("Disconnected, now scanning again")
        navBar.topItem?.title = "Searching..."
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("value updated successfully")
    }
    // ---------- /BLUETOOTH ----------


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return list.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        if indexPath.row < list.count {
            cell.textLabel?.text = list.reversed()[indexPath.row] //latest values auto pushed to top
            cell.textLabel?.font = UIFont(name: (cell.textLabel?.font.fontName)!, size: 30)
            cell.textLabel?.textAlignment = .center
            cell.isUserInteractionEnabled = false
        }
        return cell
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: nil)
        navBar.topItem?.title = "Searching..."
    }

    override func viewDidAppear(_ animated: Bool) {
        navBar.sizeToFit()
    }


    //Sends clear command to ESP32 over the BLE Characteristic
    @IBAction func clearButton(_ sender: Any) {

        let dialog = UIAlertController(title: "Delete Data?", message: "This will remove all current laptimes from the timer device", preferredStyle: .alert)

        let delete = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) -> Void in
            let clear: Data? = "clear".data(using: .utf8) // Proudly stolen from objc.io
            self.list = []
            self.TableView.reloadData()
            self.peripheral.writeValue(clear!, for: self.lapTimeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        })

        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
        }

        dialog.addAction(delete)
        dialog.addAction(cancel)

        self.present(dialog, animated: true, completion: nil)
    }
}
