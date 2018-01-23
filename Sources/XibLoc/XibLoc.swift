/*
 * XibLoc.swift
 * Localizer
 *
 * Created by François Lamboley on 12/7/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



public extension String {
	
	public func applying(xibLocInfo: XibLocResolvingInfo<String, String>) -> String {
		return ParsedXibLoc(source: self, parserHelper: StringParserHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: StringParserHelper.self)
	}
	
	public func applying(xibLocInfo: XibLocResolvingInfo<String, NSMutableAttributedString>) -> NSMutableAttributedString {
		return ParsedXibLoc(source: self, parserHelper: StringParserHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: NSMutableAttributedStringParserHelper.self)
	}
	
	public func applying(xibLocInfo: XibLocResolvingInfo<NSMutableAttributedString, NSMutableAttributedString>, defaultAttributes: [NSAttributedStringKey: Any]?) -> NSMutableAttributedString {
		/* We don't call “applying” directly on the mutable string because there
		 * is no need to copy the mutable string (see implementation of applying) */
		let attributedString = NSMutableAttributedString(string: self, attributes: defaultAttributes)
		return ParsedXibLoc(source: attributedString, parserHelper: NSMutableAttributedStringParserHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: NSMutableAttributedStringParserHelper.self)
	}
	
}

public extension NSAttributedString {
	
	public func applying(xibLocInfo: XibLocResolvingInfo<NSMutableAttributedString, NSMutableAttributedString>) -> NSMutableAttributedString {
		/* Even if self is already an NSMutableString, we have to copy it before
		 * passing it to the ParsedXibLoc, because it will modify it. */
		let resolved = ParsedXibLoc(source: NSMutableAttributedString(attributedString: self), parserHelper: NSMutableAttributedStringParserHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: NSMutableAttributedStringParserHelper.self)
		return resolved
	}
	
}

public extension NSMutableAttributedString {
	
	public func apply(xibLocInfo: XibLocResolvingInfo<NSMutableAttributedString, NSMutableAttributedString>) {
		let resolved = ParsedXibLoc(source: self, parserHelper: NSMutableAttributedStringParserHelper.self, forXibLocResolvingInfo: xibLocInfo).resolve(xibLocResolvingInfo: xibLocInfo, returnTypeHelperType: NSMutableAttributedStringParserHelper.self)
		replaceCharacters(in: NSRange(location: 0, length: length), with: resolved)
	}
	
}