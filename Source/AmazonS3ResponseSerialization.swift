//
//  AmazonS3ResponseSerialization.swift
//  AmazonS3RequestManager
//
//  Created by Anthony Miller on 10/5/15.
//  Copyright © 2015 Anthony Miller. All rights reserved.
//

import Foundation

import Alamofire
import SWXMLHash

extension Request {
    
    /// The domain used for creating all Alamofire errors.
    public static let S3ErrorDomain = "org.cocoapods.AmazonS3RequestManager.Error"
    
    
    /**
     Adds a handler to be called once the request has finished.
     The handler passes the result data as an `S3BucketObjectList`.
     
     - parameter completionHandler: The code to be executed once the request has finished.
     
     - returns: The request.
     */
    public func responseS3BucketObjectsList(completionHandler: Response<S3BucketObjectList, NSError> -> Void) -> Self {
        return responseS3Object(completionHandler)
    }
    
    /**
     Adds a handler to be called once the request has finished.
     The handler passes the result data as a populated object determined by the generic response type paramter.
     
     - parameter completionHandler: The code to be executed once the request has finished.
     
     - returns: The request.
     */
    public func responseS3Object<T: ResponseObjectSerializable where T.RepresentationType == XMLIndexer>
        (completionHandler: Response<T, NSError> -> Void) -> Self {
        return response(responseSerializer: Request.s3ObjectResponseSerializer(), completionHandler: completionHandler)
    }
    
    /**
     Creates a response serializer that serializes an object from an Amazon S3 response and parses any errors from the Amazon S3 Service.
     
     - returns: A data response serializer
     */
    static func s3ObjectResponseSerializer<T: ResponseObjectSerializable
        where T.RepresentationType == XMLIndexer>() -> ResponseSerializer<T, NSError> {
        return ResponseSerializer<T, NSError> { request, response, data, error in
            let result = XMLResponseSerializer().serializeResponse(request, response, data, nil)
            
            switch result {
            case .Success(let xml):
                if let error = amazonS3ResponseError(forXML: xml) ?? error { return .Failure(error) }
                
                if let response = response, responseObject = T(response: response, representation: xml) {
                    return .Success(responseObject)
                    
                } else {
                    let failureReason = "XML could not be serialized into response object: \(xml)"
                    let userInfo: [NSObject: AnyObject] = [NSLocalizedFailureReasonErrorKey: failureReason]
                    let error = NSError(domain: S3ErrorDomain, code: Error.Code.DataSerializationFailed.rawValue, userInfo: userInfo)
                    return .Failure(error)
                }
                
            case .Failure(let error): return .Failure(error)
            }
        }
    }
    
    /**
     Adds a handler to be called once the request has finished.
     
     - parameter completionHandler: The code to be executed once the request has finished.
     
     - returns: The request.
     */
    public func responseS3Data(completionHandler: Response<NSData, NSError> -> Void) -> Self {
        return response(responseSerializer: Request.s3DataResponseSerializer(), completionHandler: completionHandler)
    }
    
    /**
     Creates a response serializer that parses any errors from the Amazon S3 Service and returns the associated data.
     
     - returns: A data response serializer
     */
    static func s3DataResponseSerializer() -> ResponseSerializer<NSData, NSError> {
        return ResponseSerializer { request, response, data, error in
            guard let data = data else {
                let failureReason = "The response did not include any data."
                let userInfo: [NSObject: AnyObject] = [NSLocalizedFailureReasonErrorKey: failureReason]
                let error = NSError(domain: S3ErrorDomain, code: Error.Code.DataSerializationFailed.rawValue, userInfo: userInfo)
                return .Failure(error)
            }
            
            let result = XMLResponseSerializer().serializeResponse(request, response, data, nil)
            
            switch result {
            case .Success(let xml):
                if let error = amazonS3ResponseError(forXML: xml) { return .Failure(error) }
                
            case .Failure(let error): return .Failure(error)
            }
            
            guard error == nil else { return .Failure(error!) }
            
            return .Success(data)
        }
    }
    
    /**
     Creates a response serializer that parses XML data and returns an XML indexer.
     
     - returns: A XML indexer
     */
    static func XMLResponseSerializer() -> ResponseSerializer<XMLIndexer, NSError> {
        return ResponseSerializer { request, response, data, error in
            guard error == nil else { return .Failure(error!) }
            
            guard let validData = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                let userInfo: [NSObject: AnyObject] = [NSLocalizedFailureReasonErrorKey: failureReason]
                let error = NSError(domain: S3ErrorDomain, code: Error.Code.DataSerializationFailed.rawValue, userInfo: userInfo)
                return .Failure(error)
            }
            
            let xml = SWXMLHash.parse(validData)
            return .Success(xml)
        }
    }
    
    /**
     Adds a handler to be called once the request has finished.
     The handler passes the AmazonS3 meta data from the response's headers.
     
     - parameter completionHandler: The code to be executed once the request has finished.
     
     - returns: The request.
     */
    public func responseS3MetaData(completionHandler: Response<S3ObjectMetaData, NSError> -> Void) -> Self {
        return response(responseSerializer: Request.s3MetaDataResponseSerializer(), completionHandler: completionHandler)
    }
    
    /**
     Creates a response serializer that parses any errors from the Amazon S3 Service and returns the response's meta data.
     
     - returns: A metadata response serializer
     */
    static func s3MetaDataResponseSerializer() -> ResponseSerializer<S3ObjectMetaData, NSError> {
        return ResponseSerializer { request, response, data, error in
            guard error == nil else { return .Failure(error!) }
            
            guard let response = response else {
                let failureReason = "No response data was found."
                let userInfo: [NSObject: AnyObject] = [NSLocalizedFailureReasonErrorKey: failureReason]
                let error = NSError(domain: S3ErrorDomain, code: Error.Code.DataSerializationFailed.rawValue, userInfo: userInfo)
                return .Failure(error)
            }
            
            guard let metaData = S3ObjectMetaData(response: response) else {
                let failureReason = "No meta data was found."
                let userInfo: [NSObject: AnyObject] = [NSLocalizedFailureReasonErrorKey: failureReason]
                let error = NSError(domain: S3ErrorDomain, code: Error.Code.DataSerializationFailed.rawValue, userInfo: userInfo)
                return .Failure(error)
            }
            
            return .Success(metaData)
        }
    }
    
    /*
     *  MARK: - Errors
     */
    
    private static func amazonS3ResponseError(forXML xml: XMLIndexer) -> NSError? {
        guard let errorCodeString = xml["Error"]["Code"].element?.text,
            error = AmazonS3Error(rawValue: errorCodeString) else { return nil }
        
        let errorMessage = xml["Error"]["Message"].element?.text
        return error.error(failureReason: errorMessage)
    }
    
}