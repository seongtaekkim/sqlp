# 00. outline







![스크린샷 2024-03-01 오후 2.21.44](/Users/staek/Library/Application Support/typora-user-images/스크린샷 2024-03-01 오후 2.21.44.png)



DBMS 가 SQL을 처리하는 과정을 설명하고, 특히 SQL파싱과 최적화 단계에서 부하가 발생하는 원리에 대해 자세히 다른다.

- 바인드변수 중요성과 부작용, 해법을 살펴본다.
- 바인드 변수로 인한 과도한 Parse Call 에 의해 생기는 부하는 피하기 어려운데, 커서를 세션혹은 애플리케이션에 캐싱함으로 서 Parse Call을 일으키지 않는 방법을 설명한다.
- Static Sql, Dynamic SQL 의미를 명확히 하고, 라이브러리 캐시에 부하를 최소화 하면서 필요할 때에만 Dynamic SQL을 사용할 수 있도록 사용기준을 제시하려고 한다.
- Static SQL 구현기법 몇가지를 소개한다.













