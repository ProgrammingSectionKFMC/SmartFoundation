(function () {
    "use strict";

    const form =
        document.getElementById("change-password-required-form");

    if (!form) {
        return;
    }

    const currentPassword =
        document.getElementById("current-password");

    const newPassword =
        document.getElementById("new-password");

    const confirmPassword =
        document.getElementById("confirm-password");

    const strengthContainer =
        document.getElementById("password-strength");

    const strengthBar =
        document.getElementById("strength-bar");

    const strengthText =
        document.getElementById("strength-text");

    const checkLength =
        document.getElementById("check-length");

    const checkUppercase =
        document.getElementById("check-uppercase");

    const checkLowercase =
        document.getElementById("check-lowercase");

    const checkNumber =
        document.getElementById("check-number");

    const matchBox =
        document.getElementById("password-match");

    const errorBox =
        document.getElementById("password-error");

    const submitButton =
        document.getElementById("btn-change-password");

    const submitText =
        document.getElementById("btn-change-password-text");

    const submitSpinner =
        document.getElementById("btn-change-password-spinner");


    // =====================================================
    // Password Policy
    // =====================================================

    function getPasswordStatus(password) {
        return {
            length: password.length >= 12,
            uppercase: /[A-Z]/.test(password),
            lowercase: /[a-z]/.test(password),
            number: /[0-9]/.test(password)
        };
    }


    function isPasswordValid(password) {
        const status =
            getPasswordStatus(password);

        return (
            status.length &&
            status.uppercase &&
            status.lowercase &&
            status.number
        );
    }


    // =====================================================
    // Password Rules
    // =====================================================

    function setRuleState(element, valid) {
        if (!element) {
            return;
        }

        element.classList.remove(
            "valid",
            "invalid"
        );

        element.classList.add(
            valid
                ? "valid"
                : "invalid"
        );

        const icon =
            element.querySelector("i");

        if (!icon) {
            return;
        }

        icon.className =
            valid
                ? "fa-solid fa-circle-check"
                : "fa-solid fa-circle-xmark";
    }


    // =====================================================
    // Password Strength
    // =====================================================

    function updatePasswordStrength() {
        const password =
            newPassword?.value ?? "";

        if (!password) {
            strengthContainer?.classList.add("hidden");

            if (strengthBar) {
                strengthBar.style.width = "0%";
                strengthBar.className =
                    "password-strength-bar";
            }

            if (strengthText) {
                strengthText.textContent = "";
                strengthText.className =
                    "password-strength-text";
            }

            setRuleState(checkLength, false);
            setRuleState(checkUppercase, false);
            setRuleState(checkLowercase, false);
            setRuleState(checkNumber, false);

            return;
        }

        strengthContainer?.classList.remove("hidden");

        const status =
            getPasswordStatus(password);

        setRuleState(
            checkLength,
            status.length
        );

        setRuleState(
            checkUppercase,
            status.uppercase
        );

        setRuleState(
            checkLowercase,
            status.lowercase
        );

        setRuleState(
            checkNumber,
            status.number
        );

        const score =
            [
                status.length,
                status.uppercase,
                status.lowercase,
                status.number
            ]
            .filter(Boolean)
            .length;

        let width = "25%";
        let text = "ضعيفة";
        let barClass = "strength-weak";
        let textClass = "strength-weak-text";

        if (score === 2) {
            width = "50%";
            text = "متوسطة";
            barClass = "strength-medium";
            textClass = "strength-medium-text";
        }
        else if (score === 3) {
            width = "75%";
            text = "متوسطة";
            barClass = "strength-medium";
            textClass = "strength-medium-text";
        }
        else if (score === 4) {
            width = "100%";
            text = "قوية";
            barClass = "strength-strong";
            textClass = "strength-strong-text";
        }

        if (strengthBar) {
            strengthBar.style.width =
                width;

            strengthBar.className =
                "password-strength-bar " +
                barClass;
        }

        if (strengthText) {
            strengthText.textContent =
                text;

            strengthText.className =
                "password-strength-text " +
                textClass;
        }
    }


    // =====================================================
    // Password Match
    // =====================================================

    function updatePasswordMatch() {
        if (!matchBox) {
            return;
        }

        const password =
            newPassword?.value ?? "";

        const confirmation =
            confirmPassword?.value ?? "";

        if (!confirmation) {
            matchBox.className =
                "password-match hidden";

            matchBox.innerHTML = "";

            return;
        }

        if (password === confirmation) {
            matchBox.className =
                "password-match match-success";

            matchBox.innerHTML =
                '<i class="fa-solid fa-circle-check"></i>' +
                '<span>كلمتا المرور متطابقتان</span>';
        }
        else {
            matchBox.className =
                "password-match match-error";

            matchBox.innerHTML =
                '<i class="fa-solid fa-circle-xmark"></i>' +
                '<span>كلمتا المرور غير متطابقتين</span>';
        }
    }


    // =====================================================
    // Error
    // =====================================================

    function showError(message) {
        if (!errorBox) {
            return;
        }

        errorBox.textContent =
            message ||
            "حدث خطأ أثناء تغيير كلمة المرور.";

        errorBox.classList.remove("hidden");
    }


    function clearError() {
        if (!errorBox) {
            return;
        }

        errorBox.textContent = "";
        errorBox.classList.add("hidden");
    }


    // =====================================================
    // Loading
    // =====================================================

    function setLoading(loading) {
        if (!submitButton) {
            return;
        }

        submitButton.disabled =
            loading;

        if (submitSpinner) {
            submitSpinner.style.display =
                loading
                    ? "inline-block"
                    : "none";
        }

        if (submitText) {
            submitText.textContent =
                loading
                    ? "جاري تغيير كلمة المرور..."
                    : "تغيير كلمة المرور وتسجيل الدخول";
        }
    }


    // =====================================================
    // Show / Hide Password
    // Same mechanism as normal password modal
    // =====================================================

    document
        .querySelectorAll("[data-password-toggle]")
        .forEach(function (button) {

            button.addEventListener(
                "click",
                function () {

                    const inputId =
                        button.getAttribute(
                            "data-password-toggle"
                        );

                    if (!inputId) {
                        return;
                    }

                    const input =
                        document.getElementById(
                            inputId
                        );

                    const icon =
                        button.querySelector("i");

                    if (!input) {
                        return;
                    }

                    if (input.type === "password") {
                        input.type = "text";

                        if (icon) {
                            icon.classList.remove(
                                "fa-eye"
                            );

                            icon.classList.add(
                                "fa-eye-slash"
                            );
                        }

                        return;
                    }

                    input.type = "password";

                    if (icon) {
                        icon.classList.remove(
                            "fa-eye-slash"
                        );

                        icon.classList.add(
                            "fa-eye"
                        );
                    }
                }
            );
        });


    // =====================================================
    // Live Validation
    // =====================================================

    newPassword?.addEventListener(
        "input",
        function () {
            clearError();
            updatePasswordStrength();
            updatePasswordMatch();
        }
    );


    confirmPassword?.addEventListener(
        "input",
        function () {
            clearError();
            updatePasswordMatch();
        }
    );


    currentPassword?.addEventListener(
        "input",
        clearError
    );


    // =====================================================
    // Trim same as normal form
    // =====================================================

    [
        currentPassword,
        newPassword,
        confirmPassword
    ]
    .forEach(function (input) {
        input?.addEventListener(
            "blur",
            function () {
                this.value =
                    this.value.trim();
            }
        );
    });


    // =====================================================
    // Submit
    // =====================================================

    form.addEventListener(
        "submit",
        async function (event) {

            event.preventDefault();

            clearError();

            const current =
                (currentPassword?.value ?? "")
                    .trim();

            const password =
                (newPassword?.value ?? "")
                    .trim();

            const confirmation =
                (confirmPassword?.value ?? "")
                    .trim();


            // ---------------------------------------------
            // Required fields
            // ---------------------------------------------

            if (!current) {
                showError(
                    "جميع الحقول مطلوبة"
                );

                currentPassword?.focus();

                return;
            }


            if (!password) {
                showError(
                    "جميع الحقول مطلوبة"
                );

                newPassword?.focus();

                return;
            }


            if (!confirmation) {
                showError(
                    "جميع الحقول مطلوبة"
                );

                confirmPassword?.focus();

                return;
            }


            // ---------------------------------------------
            // Matching
            // ---------------------------------------------

            if (password !== confirmation) {
                showError(
                    "كلمة المرور الجديدة وتأكيد كلمة المرور غير متطابقتين"
                );

                confirmPassword?.focus();

                return;
            }


            // ---------------------------------------------
            // Minimum length
            // ---------------------------------------------

            if (password.length < 12) {
                showError(
                    "كلمة المرور يجب أن لا تقل عن 12 خانة"
                );

                newPassword?.focus();

                return;
            }


            // ---------------------------------------------
            // Uppercase
            // ---------------------------------------------

            if (!/[A-Z]/.test(password)) {
                showError(
                    "كلمة المرور يجب أن تحتوي على حرف إنجليزي كبير واحد على الأقل (A-Z)"
                );

                newPassword?.focus();

                return;
            }


            // ---------------------------------------------
            // Lowercase
            // ---------------------------------------------

            if (!/[a-z]/.test(password)) {
                showError(
                    "كلمة المرور يجب أن تحتوي على حرف إنجليزي صغير واحد على الأقل (a-z)"
                );

                newPassword?.focus();

                return;
            }


            // ---------------------------------------------
            // Number
            // ---------------------------------------------

            if (!/[0-9]/.test(password)) {
                showError(
                    "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل (0-9)"
                );

                newPassword?.focus();

                return;
            }


            // ---------------------------------------------
            // Current != New
            // ---------------------------------------------

            if (current === password) {
                showError(
                    "كلمة المرور الجديدة يجب أن تختلف عن الحالية"
                );

                newPassword?.focus();

                return;
            }


            setLoading(true);


            try {

                /*
                 * IMPORTANT:
                 * Use exactly the same request contract
                 * used by the working normal password modal.
                 *
                 * Controller expects JSON:
                 * {
                 *     oldPassword,
                 *     newPassword
                 * }
                 */

                const response =
                    await fetch(
                        "/Login/ChangePassword",
                        {
                            method: "POST",

                            headers: {
                                "Content-Type":
                                    "application/json",

                                "X-Requested-With":
                                    "XMLHttpRequest"
                            },

                            credentials:
                                "same-origin",

                            body:
                                JSON.stringify({
                                    oldPassword:
                                        current,

                                    newPassword:
                                        password
                                })
                        }
                    );


                /*
                 * Same response contract used
                 * by the normal modal.
                 */
                const result =
                    await response.json();


                if (result.success) {

                    /*
                     * Password was successfully changed.
                     * Server has changed ChangedPassword to 1.
                     *
                     * Log the user out and require
                     * a fresh login, same as existing flow.
                     */

                    if (errorBox) {
                        errorBox.textContent =
                            "تم تغيير كلمة المرور بنجاح. جاري تسجيل الخروج لإعادة تسجيل الدخول...";

                        errorBox.classList.remove(
                            "hidden"
                        );

                        errorBox.style.borderColor =
                            "#bbf7d0";

                        errorBox.style.background =
                            "#f0fdf4";

                        errorBox.style.color =
                            "#15803d";
                    }


                    if (submitText) {
                        submitText.textContent =
                            "تم تغيير كلمة المرور بنجاح";
                    }


                    setTimeout(
                        function () {
                            window.location.href =
                                "/Login?logout=2";
                        },
                        1000
                    );

                    return;
                }


                showError(
                    result.message ||
                    "فشل تغيير كلمة المرور"
                );

            }
            catch (error) {

                showError(
                    "حدث خطأ أثناء تغيير كلمة المرور"
                );

            }
            finally {

                /*
                 * Do not reactivate the button
                 * if we are already redirecting
                 * after successful change.
                 */

                setLoading(false);

            }
        }
    );


    // =====================================================
    // Initial State
    // =====================================================

    updatePasswordStrength();
    updatePasswordMatch();

})();