package com.ceos23.spring_boot.cgv.service.auth;

import com.ceos23.spring_boot.cgv.domain.auth.RefreshToken;
import com.ceos23.spring_boot.cgv.domain.user.User;
import com.ceos23.spring_boot.cgv.domain.user.UserRole;
import com.ceos23.spring_boot.cgv.dto.auth.LoginRequest;
import com.ceos23.spring_boot.cgv.dto.auth.LoginResponse;
import com.ceos23.spring_boot.cgv.dto.auth.SignupRequest;
import com.ceos23.spring_boot.cgv.dto.auth.TokenRefreshRequest;
import com.ceos23.spring_boot.cgv.dto.auth.TokenRefreshResponse;
import com.ceos23.spring_boot.cgv.global.exception.BadRequestException;
import com.ceos23.spring_boot.cgv.global.exception.ConflictException;
import com.ceos23.spring_boot.cgv.global.exception.ErrorCode;
import com.ceos23.spring_boot.cgv.global.exception.NotFoundException;
import com.ceos23.spring_boot.cgv.global.logging.AuditLogService;
import com.ceos23.spring_boot.cgv.global.logging.BusinessMetricRecorder;
import com.ceos23.spring_boot.cgv.global.security.CustomUserDetails;
import com.ceos23.spring_boot.cgv.global.security.TokenProvider;
import com.ceos23.spring_boot.cgv.repository.auth.RefreshTokenRepository;
import com.ceos23.spring_boot.cgv.repository.user.UserRepository;
import java.time.LocalDateTime;
import java.util.Map;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenProvider tokenProvider;
    private final AuditLogService auditLogService;
    private final BusinessMetricRecorder businessMetricRecorder;

    public AuthService(
            UserRepository userRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordEncoder passwordEncoder,
            TokenProvider tokenProvider,
            AuditLogService auditLogService,
            BusinessMetricRecorder businessMetricRecorder
    ) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.auditLogService = auditLogService;
        this.businessMetricRecorder = businessMetricRecorder;
    }

    public void signup(SignupRequest request) {
        long startTime = System.currentTimeMillis();

        try {
            if (userRepository.findByEmail(request.email()).isPresent()) {
                throw new ConflictException(ErrorCode.CONFLICT, "이미 가입된 이메일입니다.");
            }

            User user = new User(
                    request.name(),
                    request.email(),
                    passwordEncoder.encode(request.password()),
                    UserRole.USER
            );

            userRepository.save(user);
            auditLogService.info("auth_signup_success", Map.of("userId", user.getId()));
            businessMetricRecorder.recordAuthEvent("signup", "success", System.currentTimeMillis() - startTime);
        } catch (ConflictException exception) {
            auditLogService.warn("auth_signup_failed", Map.of("reason", exception.getErrorCode().getCode()));
            businessMetricRecorder.recordAuthEvent("signup", "failure", System.currentTimeMillis() - startTime);
            throw exception;
        }
    }

    @Transactional
    public LoginResponse login(LoginRequest request) {
        long startTime = System.currentTimeMillis();

        try {
            User user = userRepository.findByEmail(request.email())
                    .orElseThrow(() -> new NotFoundException(ErrorCode.USER_NOT_FOUND));

            if (!passwordEncoder.matches(request.password(), user.getPassword())) {
                throw new BadRequestException(ErrorCode.BAD_REQUEST, "이메일 또는 비밀번호가 올바르지 않습니다.");
            }

            Authentication authentication = createAuthentication(user);
            String accessToken = tokenProvider.createAccessToken(user.getId(), authentication);
            String refreshToken = tokenProvider.createRefreshToken(user.getId());

            saveOrUpdateRefreshToken(user.getId(), refreshToken);
            auditLogService.info("auth_login_success", Map.of("userId", user.getId()));
            businessMetricRecorder.recordAuthEvent("login", "success", System.currentTimeMillis() - startTime);

            return new LoginResponse(accessToken, refreshToken);
        } catch (NotFoundException | BadRequestException exception) {
            auditLogService.warn("auth_login_failed", Map.of("reason", resolveErrorCode(exception)));
            businessMetricRecorder.recordAuthEvent("login", "failure", System.currentTimeMillis() - startTime);
            throw exception;
        }
    }

    public TokenRefreshResponse refresh(TokenRefreshRequest request) {
        long startTime = System.currentTimeMillis();

        try {
            String refreshToken = request.refreshToken();

            if (!tokenProvider.validateRefreshToken(refreshToken)) {
                throw new BadRequestException(ErrorCode.BAD_REQUEST, "유효하지 않은 refresh token 입니다.");
            }

            Long userId = Long.parseLong(tokenProvider.getTokenUserId(refreshToken));
            RefreshToken savedRefreshToken = refreshTokenRepository.findByUserId(userId)
                    .orElseThrow(() -> new BadRequestException(ErrorCode.BAD_REQUEST, "저장된 refresh token 이 없습니다."));

            if (!savedRefreshToken.getToken().equals(refreshToken)) {
                throw new BadRequestException(ErrorCode.BAD_REQUEST, "refresh token 이 일치하지 않습니다.");
            }

            if (savedRefreshToken.isExpired()) {
                throw new BadRequestException(ErrorCode.BAD_REQUEST, "만료된 refresh token 입니다.");
            }

            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new NotFoundException(ErrorCode.USER_NOT_FOUND));

            Authentication authentication = createAuthentication(user);
            String newAccessToken = tokenProvider.createAccessToken(user.getId(), authentication);
            String newRefreshToken = tokenProvider.createRefreshToken(user.getId());

            savedRefreshToken.update(
                    newRefreshToken,
                    LocalDateTime.now().plusSeconds(
                            tokenProvider.getRefreshTokenValidityInMilliseconds() / 1000
                    )
            );

            auditLogService.info("auth_refresh_success", Map.of("userId", userId));
            businessMetricRecorder.recordAuthEvent("refresh", "success", System.currentTimeMillis() - startTime);

            return new TokenRefreshResponse(newAccessToken, newRefreshToken);
        } catch (BadRequestException | NotFoundException exception) {
            auditLogService.warn("auth_refresh_failed", Map.of("reason", resolveErrorCode(exception)));
            businessMetricRecorder.recordAuthEvent("refresh", "failure", System.currentTimeMillis() - startTime);
            throw exception;
        }
    }

    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
        auditLogService.info("auth_logout_success", Map.of("userId", userId));
        businessMetricRecorder.recordAuthEvent("logout", "success", 0L);
    }

    private Authentication createAuthentication(User user) {
        CustomUserDetails userDetails = new CustomUserDetails(user);

        return new UsernamePasswordAuthenticationToken(
                userDetails,
                null,
                userDetails.getAuthorities()
        );
    }

    private void saveOrUpdateRefreshToken(Long userId, String refreshToken) {
        LocalDateTime expiresAt = LocalDateTime.now().plusSeconds(
                tokenProvider.getRefreshTokenValidityInMilliseconds() / 1000
        );

        refreshTokenRepository.findByUserId(userId)
                .ifPresentOrElse(
                        savedToken -> savedToken.update(refreshToken, expiresAt),
                        () -> refreshTokenRepository.save(
                                new RefreshToken(userId, refreshToken, expiresAt)
                        )
                );
    }

    private String resolveErrorCode(RuntimeException exception) {
        if (exception instanceof BadRequestException badRequestException) {
            return badRequestException.getErrorCode().getCode();
        }

        if (exception instanceof ConflictException conflictException) {
            return conflictException.getErrorCode().getCode();
        }

        if (exception instanceof NotFoundException notFoundException) {
            return notFoundException.getErrorCode().getCode();
        }

        return ErrorCode.INTERNAL_SERVER_ERROR.getCode();
    }
}
