// choreando observables

import RxSwift
import RxCocoa

extension Observable {
    public static func system<State>(
        _ initialState: State,
        accumulator: @escaping (State, Element) -> State,
        scheduler: SchedulerType,
        feedback: (Observable<State>) -> Observable<Element>...
        ) -> Observable<State> {
        return Observable<State>.deferred {
            let replaySubject = ReplaySubject<State>.create(bufferSize: 1)

            let inputs: Observable<Element> = Observable.merge(feedback.map { $0(replaySubject.asObservable()) })
                .observeOn(scheduler)

            return inputs.scan(initialState, accumulator: accumulator)
                .startWith(initialState)
                .do(onNext: { output in
                    replaySubject.onNext(output)
                })
        }
    }
}
