import CoreNFC
import Foundation

final class NFCManager: NSObject {

    private let stickerKey = "registeredNFCTagID"

    nonisolated(unsafe) private var session: NFCNDEFReaderSession?
    nonisolated(unsafe) private var purpose: Purpose = .register
    nonisolated(unsafe) private var onResult: ((Result<String, Error>) -> Void)?

    private enum Purpose { case register, validate }

    // MARK: - Public API

    var registeredTagID: String? {
        UserDefaults.standard.string(forKey: stickerKey)
    }

    func registerTag(completion: @escaping (Result<String, Error>) -> Void) {
        start(purpose: .register, message: "Hold your phone near your Sunny sticker.", completion: completion)
    }

    func validateTag(completion: @escaping (Bool) -> Void) {
        start(purpose: .validate, message: "Tap your phone to Sunny's sticker.") { [weak self] result in
            switch result {
            case .success(let id):
                completion(id == self?.registeredTagID)
            case .failure:
                completion(false)
            }
        }
    }

    // MARK: - Private

    private func start(purpose: Purpose, message: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(NFCError.unavailable))
            return
        }
        self.purpose = purpose
        self.onResult = completion
        session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session?.alertMessage = message
        session?.begin()
    }

    private func finish(with result: Result<String, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.onResult?(result)
            self?.onResult = nil
        }
    }

    enum NFCError: LocalizedError {
        case unavailable, unreadable, writeFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:  return "NFC is not available on this device."
            case .unreadable:   return "Could not read the sticker. Try again."
            case .writeFailed:  return "Could not write to sticker. Try again."
            }
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let err = error as? NFCReaderError,
           err.code == .readerSessionInvalidationErrorUserCanceled { return }
        if let err = error as? NFCReaderError,
           err.code == .readerSessionInvalidationErrorFirstNDEFTagRead { return }
        finish(with: .failure(error))
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used — we use tag-based detection below
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found. Try again.")
            finish(with: .failure(NFCError.unreadable))
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }

            if error != nil {
                session.invalidate(errorMessage: "Connection failed. Try again.")
                self.finish(with: .failure(NFCError.unreadable))
                return
            }

            switch self.purpose {
            case .register:
                self.writeNewID(to: tag, session: session)
            case .validate:
                self.readID(from: tag, session: session)
            }
        }
    }

    // MARK: - Write a UUID onto the tag (register)

    private func writeNewID(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        let uuid = UUID().uuidString
        let payload = NFCNDEFPayload(
            format: .unknown,
            type: Data(),
            identifier: Data(),
            payload: Data(uuid.utf8)
        )
        let message = NFCNDEFMessage(records: [payload])

        tag.queryNDEFStatus { [weak self] status, _, error in
            guard let self else { return }

            if error != nil || status == .notSupported {
                session.invalidate(errorMessage: "This sticker is not supported.")
                self.finish(with: .failure(NFCError.writeFailed))
                return
            }

            tag.writeNDEF(message) { [weak self] writeError in
                guard let self else { return }
                if writeError != nil {
                    session.invalidate(errorMessage: "Write failed. Sticker may be locked.")
                    self.finish(with: .failure(NFCError.writeFailed))
                    return
                }
                UserDefaults.standard.set(uuid, forKey: self.stickerKey)
                session.alertMessage = "Sunny's sticker is set!"
                session.invalidate()
                self.finish(with: .success(uuid))
            }
        }
    }

    // MARK: - Read UUID from tag (validate)

    private func readID(from tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { [weak self] message, error in
            guard let self else { return }

            if error != nil || message == nil {
                session.invalidate(errorMessage: "Could not read sticker.")
                self.finish(with: .failure(NFCError.unreadable))
                return
            }

            guard let record = message?.records.first,
                  let id = String(data: record.payload, encoding: .utf8),
                  !id.isEmpty else {
                session.invalidate(errorMessage: "No data on sticker.")
                self.finish(with: .failure(NFCError.unreadable))
                return
            }

            session.invalidate()
            self.finish(with: .success(id))
        }
    }
}
