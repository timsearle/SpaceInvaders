import Foundation
import Emul8080r



final class InvaderMachine {
    enum ButtonState {
        case down
        case up
    }

    private let queue = DispatchQueue(label: "dev.searle.invader-machine")
    private let cpu: CPU
    private let shiftRegister = ShiftRegister()

    private var inputPorts: [UInt8] = [0b00001110, 0, 0, 0]
    
    var videoMemory: [UInt8] {
        Array(cpu.memory[0x2400...0x3FFF])
    }

    init(rom: Data, loggingEnabled: Bool = false) {
        cpu = CPU(memory: [UInt8](repeating: 0, count: 65536), systemClock: Clock())
        cpu.bus = self
        cpu.load(rom.map { $0 })
    }

    var lastTime = Double(0)
    var nextInterruptTime = Double(0)
    var interruptValue = UInt8(1)

    func play(onError: @escaping (Error) -> ()) {
        queue.async {
            while true {
                do {
                    try self.cpu.start(interrupter: { () -> UInt8 in
                        let now = Clock().currentMicroseconds()

                        if self.lastTime == 0.0 {
                            self.lastTime = now
                            self.nextInterruptTime = self.lastTime + 16000
                            return 1
                        }

                        if now > self.nextInterruptTime {
                            self.interruptValue = self.interruptValue == 1 ? 2 : 1
                            self.nextInterruptTime = now + 8000
                            return self.interruptValue
                        }

                        return 0
                    })
                } catch {
                    DispatchQueue.main.async {
                        print(error)
                        onError(error)
                    }
                    break
                }
            }
        }
    }

    func fire(state: ButtonState) {
        switch state {
        case .down:
            inputPorts[1] |= 0x10
        case .up:
            inputPorts[1] &= ~0x10
        }
    }

    func left(state: ButtonState) {
        switch state {
        case .down:
            inputPorts[1] |= 0x20
        case .up:
            inputPorts[1] &= ~0x20
        }
    }

    func right(state: ButtonState) {
        switch state {
        case .down:
            inputPorts[1] |= 0x40
        case .up:
            inputPorts[1] &= ~0x40
        }
    }

    func coin(state: ButtonState) {
        switch state {
        case .down:
            inputPorts[1] |= 0x01
        case .up:
            inputPorts[1] &= ~0x01
        }
    }

    func start1P(state: ButtonState) {
        switch state {
        case .down: 
            inputPorts[1] |= 0x04
        case .up:
            inputPorts[1] &= ~0x04
        }
    }

    func start2P(state: ButtonState) {
        switch state {
        case .down:
            inputPorts[1] |= 0x02
        case .up:
            inputPorts[1] &= ~0x02
        }
    }
}

extension InvaderMachine: IOBus {
    func machineIN(port: UInt8) -> UInt8 {
        switch port {
        case 3:
            return shiftRegister.in(port: port)
        default:
            return inputPorts[Int(port)]
        }
    }

    func machineOUT(port: UInt8, accumulator: UInt8) {
        switch port {
        case 2, 4:
            return shiftRegister.out(port: port, value: accumulator)
        default:
            break
        }
    }
}
