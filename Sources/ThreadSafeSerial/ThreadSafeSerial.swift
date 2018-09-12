//
//  ThreadSafeSerialPort.swift
//  ThreadSafeSerialPort
//
//  Created by DasenB on 10.09.18.
//

import Foundation
import IOKit
import IOKit.serial
import IOKit.usb
import IOKit.hid
import IOKit.hidsystem
import SwiftSerial

public struct SerialStatus {
    let path: String?
    let connected: Bool
    let baude: BaudRate
}

public protocol ThreadSafeSerialDelegate {
    func connected(serialport: ThreadSafeSerial)
    func disconnected(serialport: ThreadSafeSerial)
}

public class ThreadSafeSerial: USBWatcherDelegate {
    
    private var serialPort: SerialPort? = nil
    private var path: String? = nil
    private var connected: Bool = false
    
    private var watcher: USBWatcher? = nil
    
    private var baud: BaudRate = .baud9600
    private var timeout: Int = 1
    private var minimumBytesToRead: Int = 1
    
    private let queue = DispatchQueue(label: "ThreadSafeSerial_serialportQueue")
    private let usbQueue = DispatchQueue(label: "ThreadSafeSerial_usbObservationQueue")
    
    private var waitingOpen = false
    private var returnOpen = false
    
    private var waitingClose = false
    private var returnClose = false
    
    private var waitingRead = false
    private var returnRead: String? = nil
    private var starttimeRead: Date? = nil
    
    private var delegate: ThreadSafeSerialDelegate? = nil
    
    public var status : SerialStatus {
        get {
            return SerialStatus.init(path: self.path, connected: self.connected, baude: self.baud)
        }
    }
    
    init() {
        self.watcher = USBWatcher(delegate: self)
    }
    
    func open(path: String) -> Bool {
        self.waitingOpen = true
        if self.connected { return false }
        let task = DispatchWorkItem {
            let serial = SerialPort(path: path)
            serial.setSettings(receiveRate: self.baud, transmitRate: self.baud, minimumBytesToRead: self.minimumBytesToRead, timeout: self.timeout)
            do {
                try serial.openPort()
                self.serialPort = serial
                self.path = path
                self.connected = true
                self.returnOpen = true
                self.waitingOpen = false
            } catch {
                self.returnOpen = false
                self.connected = false
                self.waitingOpen = false
                return
            }
        }
        self.queue.sync(execute: task)
        while self.waitingOpen {
        }
        return returnOpen
    }
    
    // always returns true after closing the serialport
    func close() -> Bool {
        waitingClose = true
        let task = DispatchWorkItem {
            if self.serialPort != nil {
                self.serialPort!.closePort()
            }
            self.path = nil
            self.connected = false
            self.waitingClose = false
        }
        queue.sync(execute: task)
        while waitingClose {
        }
        return true
    }
    
    // timeout in milliseconds
    func readLine(timeout: Int) -> String? {
        if connected == false { return nil }
        waitingRead = true
        returnRead = nil
        self.starttimeRead = Date()
        let task = DispatchWorkItem {
            do {
                if self.serialPort == nil {
                    return
                }
                if !self.connected {
                    return
                }
                let str = try self.serialPort!.readLine()
                self.returnRead = str
                self.waitingRead = false
            } catch {
                self.waitingRead = false
                return
            }
        }
        queue.sync(execute: task)
        while waitingRead && connected {
            if(timeout > 0) {
                let duration = self.starttimeRead!.timeIntervalSinceNow * -1000
                if Int(duration) > timeout {
                    waitingRead = false
                }
            }
        }
        if(!task.isCancelled) {
            task.cancel()
        }
        return self.returnRead
    }
    
    func write(string: String) -> Bool {
        if connected == false { return false }
        return false
    }
    
    func deviceAdded(_ device: io_object_t) {
        print("device added: \(device.name() ?? "<unknown>")")
        if self.delegate != nil {
            let notificationTask = DispatchWorkItem {
                self.delegate!.connected(serialport: self)
            }
            let notificationThread = DispatchQueue.init(label: "ThreadSafeSerial_notification")
            notificationThread.sync(execute: notificationTask)
        }
    }
    
    func deviceRemoved(_ device: io_object_t) {
        // Stop execution of serialport operations
        queue.suspend()
        var str = "removed: \(device.name() ?? "<unknown>")"
        
        // if serialport is not in use: continue normal schedule
        if !connected || self.serialPort == nil {
            print(str)
            queue.resume()
            return
        }
        
        // check wether the disconnected device was the device belonging serialport
        // if that is the case close the serialport
        let availablePorts = getSerialPortList()
        let serialPortStillAvailable = availablePorts.contains(self.path!)
        if !serialPortStillAvailable {
            if self.serialPort != nil {
                self.serialPort!.closePort()
            }
            self.path = nil
            self.connected = false
            self.waitingClose = false
            str += " closed: true"
        }
        print(str)
        
        if self.delegate != nil {
            let notificationTask = DispatchWorkItem {
                self.delegate!.disconnected(serialport: self)
            }
            let notificationThread = DispatchQueue.init(label: "ThreadSafeSerial_notification")
            notificationThread.sync(execute: notificationTask)
        }
        
        // let other serialport operations continue
        queue.resume()
    }
    
    func getSerialPortList() -> [String] {
        func findSerialDevices(deviceType: String, serialPortIterator: inout io_iterator_t ) -> kern_return_t {
            var result: kern_return_t = KERN_FAILURE
            let classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue)! //.takeUnretainedValue()
            let classesToMatchCFDictRef = classesToMatch as CFDictionary
            result = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatchCFDictRef, &serialPortIterator);
            return result
        }
        var SerialPortNameArray = [String]()
        var portIterator: io_iterator_t = 0
        let kernResult = findSerialDevices(deviceType: kIOSerialBSDModemType, serialPortIterator: &portIterator)
        if kernResult == KERN_SUCCESS {
            var serialService: io_object_t
            repeat {
                serialService = IOIteratorNext(portIterator)
                if (serialService != 0) {
                    let key: CFString! = "IOCalloutDevice" as CFString
                    let bsdPathAsCFtring: CFString? = (IORegistryEntryCreateCFProperty(serialService, key, kCFAllocatorDefault, 0).takeUnretainedValue() as! CFString)
                    let bsdPath = String(bsdPathAsCFtring!)
                    SerialPortNameArray.append(bsdPath)
                }
            } while serialService != 0
        }
        return SerialPortNameArray
    }
}
