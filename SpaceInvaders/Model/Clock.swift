import Emul8080r
import Darwin

struct Clock: SystemClock {
    func currentMicroseconds() -> Double {
        var time = timeval(tv_sec: 0, tv_usec: 0)
        gettimeofday(&time, nil)
        return Double(time.tv_sec * __darwin_time_t(1E6) + __darwin_time_t(time.tv_usec))
    }
}
