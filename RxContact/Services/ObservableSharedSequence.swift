// esto esta inspirado, y quizas afanado.

import RxSwift
import RxCocoa


private struct ObservableToken<E> : ObservableConvertibleType, Disposable {
    private let _source: Observable<E>
    private let _dispose: Cancelable

    init(source: Observable<E>, disposeAction: @escaping () -> ()) {
        _source = source
        _dispose = Disposables.create(with: disposeAction)
    }

    func dispose() {
        _dispose.dispose()
    }

    func asObservable() -> Observable<E> {
        return _source
    }
}


public class ObservableSharedSequence : SharedSequenceConvertibleType {
    public typealias E = Bool
    public typealias SharingStrategy = DriverSharingStrategy

    private let _lock = NSRecursiveLock()
    private let _variable = Variable(0)
    private let _loading: SharedSequence<SharingStrategy, Bool>

    public init() {
        _loading = _variable.asDriver()
            .map { $0 > 0 }
            .distinctUntilChanged()
    }

    fileprivate func trackActivityOfObservable<O: ObservableConvertibleType>(_ source: O) -> Observable<O.E> {
        return Observable.using({ () -> ObservableToken<O.E> in
            self.increment()
            return ObservableToken(source: source.asObservable(), disposeAction: self.decrement)
        }) { t in
            return t.asObservable()
        }
    }

    private func increment() {
        _lock.lock()
        _variable.value = _variable.value + 1
        _lock.unlock()
    }

    private func decrement() {
        _lock.lock()
        _variable.value = _variable.value - 1
        _lock.unlock()
    }

    public func asSharedSequence() -> SharedSequence<SharingStrategy, E> {
        return _loading
    }
}

extension ObservableConvertibleType {
    public func trackActivity(_ activityIndicator: ObservableSharedSequence) -> Observable<E> {
        return activityIndicator.trackActivityOfObservable(self)
    }
}
