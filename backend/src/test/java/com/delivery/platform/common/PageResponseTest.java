package com.delivery.platform.common;

import static org.assertj.core.api.Assertions.assertThat;
import java.util.List;
import org.junit.jupiter.api.Test;

class PageResponseTest {
    @Test void calculatesTotalsAndNavigationMetadata() {
        PageResponse<String> page = PageResponse.of(List.of("a", "b"), 1, 2, 5);
        assertThat(page.totalPages()).isEqualTo(3);
        assertThat(page.totalElements()).isEqualTo(5);
        assertThat(page.first()).isFalse();
        assertThat(page.last()).isFalse();
    }

    @Test void emptyResultIsBothFirstAndLast() {
        PageResponse<String> page = PageResponse.of(List.of(), 0, 20, 0);
        assertThat(page.totalPages()).isZero();
        assertThat(page.first()).isTrue();
        assertThat(page.last()).isTrue();
    }
}
