@preconcurrency import CoreNFC
import Foundation

enum NFCScanPurpose { case register, validate }

final class NFCManager: NSObject {

    private let stickerKey = "registeredNFCTagID"
    private var session: NFCTagReaderSession?

    // nonisolated(unsafe) lets delegate callbacks read/write these
    // without actor-hop; safe because session callbacks all run on .main
    nonisolated(unsafe) private var scanPurpose: NFCScanPurpose = .register
    nonisolated(unsafe) private var completion: ((Result<String, Error>) -> Void)?

    var registeredTagID: String? {
        UserDefaults.standard.string(forKey: stickerKey)
    }

    func registerTag(completion: @escaping (Result<String, Error>) -> Void) {
        beginSession(
            purpose: .register,
            message: "Hold your phone near Sunny's sticker.",
            completion: completion
        )
    }

    func validateTagForDismissal(completion: @escaping (Bool) -> Void) {
        let key = stickerKey
        beginSession(
            purpose: .validate,
            message: "Bring your phone to Sunny's sticker."
        ) { result in
            switch result {
            case .success(let id):
                completion(id == UserDefaults.standard.string(forKey: key))
            case .failure:
                completion(false)
            }
        }
    }

    private func beginSession(
        purpose: NFCScanPurpose,
        message: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard NFCTagReaderSession.readingAvailable else {
            completion(.failure(NFCError.unavailable))
            return
        }
        self.scanPurpose = purpose
        self.completion = completion
        session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: .main
        )
        session?.alertMessage = message
        session?.begin()
    }

    enum NFCError: LocalizedError {
        case unavailable, noData

        var errorDescription: String? {
            switch self {
            case .unavailable:  return "NFC is not available on this device."
            case .noData:       return "Sunny could not read this sticker."
            }
        }
    }
}

// MARK: - Delegate

extension NFCManager: NFCTagReaderSessionDelegate {

    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected.")
            return
        }
        let purpose = scanPurpose
        let key = stickerKey

        session.connect(to: tag) { [weak self] error in
            if error != nil {
                session.invalidate(errorMessage: "Connection failed.")
                Task { @MainActor [weak self] in
                    self?.completion?(.failure(NFCError.unavailable))
                    self?.completion = nil
                }
                return
            }

            guard let tagID = Self.identifier(for: tag) else {
                session.invalidate(errorMessage: "Sunny could not read this sticker.")
                Task { @MainActor [weak self] in
                    self?.completion?(.failure(NFCError.noData))
                    self?.completion = nil
                }
                return
            }

            switch purpose {
            case .register:
                UserDefaults.standard.set(tagID, forKey: key)
                session.alertMessage = "Found Sunny's spot!"
                session.invalidate()
                Task { @MainActor [weak self] in
                    self?.completion?(.success(tagID))
                    self?.completion = nil
                }
            case .validate:
                session.invalidate()
                Task { @MainActor [weak self] in
                    self?.completion?(.success(tagID))
                    self?.completion = nil
                }
            }
        }
    }

    private nonisolated static func identifier(for tag: NFCTag) -> String? {
        let data: Data
        switch tag {
        case .feliCa(let detectedTag):
            data = detectedTag.currentIDm
        case .iso15693(let detectedTag):
            data = detectedTag.identifier
        case .iso7816(let detectedTag):
            data = detectedTag.identifier
        case .miFare(let detectedTag):
            data = detectedTag.identifier
        @unknown default:
            return nil
        }

        guard !data.isEmpty else { return nil }
        return data.map { String(format: "%02x", $0) }.joined()
    }
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let err = error as? NFCReaderError,
           err.code == .readerSessionInvalidationErrorUserCanceled { return }
        Task { @MainActor [weak self] in
            self?.completion?(.failure(error))
            self?.completion = nil
        }
    }
}
