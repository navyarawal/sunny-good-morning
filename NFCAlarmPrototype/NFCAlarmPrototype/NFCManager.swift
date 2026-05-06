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
        case unavailable, noData, writeFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:  return "NFC is not available on this device."
            case .noData:       return "Sunny could not read this sticker."
            case .writeFailed:  return "Could not write to sticker — it may be write-locked."
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

            let ndefTag: NFCNDEFTag
            switch tag {
            case .feliCa(let detectedTag):
                ndefTag = detectedTag
            case .iso15693(let detectedTag):
                ndefTag = detectedTag
            case .iso7816(let detectedTag):
                ndefTag = detectedTag
            case .miFare(let detectedTag):
                ndefTag = detectedTag
            @unknown default:
                session.invalidate(errorMessage: "Unsupported sticker.")
                Task { @MainActor [weak self] in
                    self?.completion?(.failure(NFCError.noData))
                    self?.completion = nil
                }
                return
            }

            if purpose == .register {
                let uuid = UUID().uuidString
                let record = NFCNDEFPayload(
                    format: .unknown,
                    type: Data(),
                    identifier: Data(),
                    payload: Data(uuid.utf8)
                )
                ndefTag.writeNDEF(NFCNDEFMessage(records: [record])) { [weak self] writeError in
                    if writeError != nil {
                        session.invalidate(errorMessage: "Write failed — sticker may be locked.")
                        Task { @MainActor [weak self] in
                            self?.completion?(.failure(NFCError.writeFailed))
                            self?.completion = nil
                        }
                        return
                    }
                    UserDefaults.standard.set(uuid, forKey: key)
                    session.alertMessage = "Found Sunny's spot!"
                    session.invalidate()
                    Task { @MainActor [weak self] in
                        self?.completion?(.success(uuid))
                        self?.completion = nil
                    }
                }
            } else {
                ndefTag.readNDEF { [weak self] message, readError in
                    if readError != nil {
                        session.invalidate(errorMessage: "Could not read sticker.")
                        Task { @MainActor [weak self] in
                            self?.completion?(.failure(NFCError.noData))
                            self?.completion = nil
                        }
                        return
                    }
                    guard let record = message?.records.first,
                          let text = String(data: record.payload, encoding: .utf8) else {
                        session.invalidate(errorMessage: "No data on sticker.")
                        Task { @MainActor [weak self] in
                            self?.completion?(.failure(NFCError.noData))
                            self?.completion = nil
                        }
                        return
                    }
                    session.invalidate()
                    Task { @MainActor [weak self] in
                        self?.completion?(.success(text))
                        self?.completion = nil
                    }
                }
            }
        }
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
