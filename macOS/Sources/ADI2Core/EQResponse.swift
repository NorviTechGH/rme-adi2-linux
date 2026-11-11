import Foundation

/// RBJ biquad approximation for editing; not a measured RME device response.
public enum EQResponse {
    public static func decibels(profile: EQProfile, frequency: Double, sampleRate: Double = 192000) -> Double {
        guard profile.eqEnabled, frequency.isFinite, sampleRate.isFinite, sampleRate > 0, frequency > 0, frequency < sampleRate / 2 else { return 0 }
        return profile.bands.enumerated().reduce(0) { sum, entry in
            let (index,band) = entry
            guard band.frequency.isFinite,band.gainDB.isFinite,band.q.isFinite else { return sum }
            return sum + response(band:band,lowShelf:index == 0,frequency:frequency,sampleRate:sampleRate)
        }
    }
    private static func response(band: Band, lowShelf: Bool, frequency: Double, sampleRate: Double) -> Double {
        if band.gainDB == 0 && band.type == "Peak" { return 0 }
        let f0 = min(max(band.frequency,1),sampleRate * 0.499)
        let a = pow(10,band.gainDB / 40), w0 = 2 * Double.pi * f0 / sampleRate
        let alpha = sin(w0) / (2 * max(band.q,0.05)), cw = cos(w0)
        let b: [Double], d: [Double]
        switch band.type {
        case "Peak": b = [1 + alpha*a,-2*cw,1-alpha*a]; d = [1+alpha/a,-2*cw,1-alpha/a]
        case "Shelf" where lowShelf:
            let s = 2 * sqrt(a) * alpha
            b = [a*((a+1)-(a-1)*cw+s),2*a*((a-1)-(a+1)*cw),a*((a+1)-(a-1)*cw-s)]
            d = [(a+1)+(a-1)*cw+s,-2*((a-1)+(a+1)*cw),(a+1)+(a-1)*cw-s]
        case "Shelf":
            let s = 2 * sqrt(a) * alpha
            b = [a*((a+1)+(a-1)*cw+s),-2*a*((a-1)+(a+1)*cw),a*((a+1)+(a-1)*cw-s)]
            d = [(a+1)-(a-1)*cw+s,2*((a-1)-(a+1)*cw),(a+1)-(a-1)*cw-s]
        case "High Pass": b = [(1+cw)/2,-(1+cw),(1+cw)/2]; d = [1+alpha,-2*cw,1-alpha]
        case "High Cut": b = [(1-cw)/2,1-cw,(1-cw)/2]; d = [1+alpha,-2*cw,1-alpha]
        default: return 0
        }
        let w = 2 * Double.pi * frequency / sampleRate
        func magnitude(_ c:[Double]) -> Double {
            let real = c[0] + c[1] * cos(w) + c[2] * cos(2*w)
            let imaginary = -c[1] * sin(w) - c[2] * sin(2*w)
            return real * real + imaginary * imaginary
        }
        return 10 * log10(max(magnitude(b),1e-20)/max(magnitude(d),1e-20))
    }
}
