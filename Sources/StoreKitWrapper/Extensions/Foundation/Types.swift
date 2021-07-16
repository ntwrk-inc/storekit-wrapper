import struct StoreKit.SKError

public typealias Closure<T> = (T) -> Void
public typealias ResultClosure<T> = Closure<Result<T, SKError>>
