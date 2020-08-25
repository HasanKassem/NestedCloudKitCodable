//
//  CKDecoderUnkeyedContainer.swift
//  NestedCloudKitCodable
//
//  Created by Guilherme Girotto on 18/11/18.
//  Copyright © 2018 Guilherme Girotto. All rights reserved.
//

import CloudKit
import Foundation

internal class CKDecoderUnkeyedContainer: UnkeyedDecodingContainer {

    enum State {
        case records
        case elements
    }

    var records: [CKRecord]
    var codingPath: [CodingKey]

    private let elements: [Decodable]
    private let receivedRecords: [CKRecord]
    private let state: State
    private var current: Int

    private var record: CKRecord {
        return receivedRecords[current]
    }
    private var element: Decodable {
        return elements[current]
    }

    init(records: [CKRecord],
         elements: [Decodable] = [],
         receivedRecords: [CKRecord] = [],
         current: Int = 0,
         state: State,
         codingPath: [CodingKey]) {
        self.records = records
        self.codingPath = codingPath
        self.elements = elements
        self.receivedRecords = receivedRecords
        self.current = current
        self.state = state
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let keyedContainer = CKDecoderKeyedContainer<NestedKey>(records: records,
                                                                recordBeingAnalyzed: record,
                                                                codingPath: codingPath)
        return KeyedDecodingContainer(keyedContainer)
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let nestedUnkeyedContainer = CKDecoderUnkeyedContainer(records: records,
                                                               elements: elements,
                                                               receivedRecords: receivedRecords,
                                                               state: state,
                                                               codingPath: codingPath)
        return nestedUnkeyedContainer
    }

    func superDecoder() throws -> Decoder {
        return InternalCKRecordDecoder(records: records)
    }
}

extension CKDecoderUnkeyedContainer {

    var currentIndex: Int { current }

    var count: Int? {
        switch state {
        case .elements:
            return elements.count
        case .records:
            return receivedRecords.count
        }
    }

    var isAtEnd: Bool { currentIndex > (count! - 1) }

    func decodeNil() throws -> Bool { currentIndex > count! }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        switch state {
        case .records:
            return try decodeRecord()
        case .elements:
            return try decodeElement()
        }
    }

    private func decodeElement<T>() throws -> T where T: Decodable {
        guard let element = element as? T else {
            throw CKCodableError(.typeMismatch)
        }
        current += 1
        return element
    }

    private func decodeRecord<T>() throws -> T where T: Decodable {
        let element = record
        current += 1
        let decoder = InternalCKRecordDecoder(records: records, recordBeingAnalyzed: element)
        return try T(from: decoder)
    }
}
